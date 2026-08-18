defmodule ObanEvents do
  @moduledoc """
  Event bus with persistent, transactional async handlers via Oban.

  This module provides a complete event bus system that combines event registration,
  handler management, and async job dispatching in a single interface.

  ## Features

  - **Registry-based** - Compile-time event and handler registration
  - **Persistent** - Events survive restarts (stored in Oban's DB)
  - **Reliable** - Automatic retries on failure via Oban
  - **Async** - Non-blocking execution of handlers
  - **Transactional** - Works within database transactions for atomicity
  - **Observable** - Track event processing via Oban Web UI
  - **Type-safe** - Compile-time validation of events

  ## Usage

  Define your event bus in one module:

      defmodule MyApp.Events do
        use ObanEvents,
          oban: MyApp.Oban,
          queue: :my_events,
          max_attempts: 5,
          priority: 1

        @event_handlers %{
          user_created: [MyApp.EmailHandler, MyApp.AnalyticsHandler],
          user_updated: [MyApp.CacheHandler],
          order_placed: []
        }
      end

  Emit events (preferably within transactions):

      MyApp.Repo.transaction(fn ->
        with {:ok, user} <- MyApp.Repo.insert(changeset),
             {:ok, _jobs} <- MyApp.Events.emit(:user_created, %{
               user_id: user.id,
               email: user.email
             }) do
          {:ok, user}
        end
      end)

  ## Event Flow

  1. `emit/2` is called with an event name and data
  2. Registry looks up all handlers for that event
  3. Oban jobs are created (one per handler)
  4. Jobs are persisted to the database within the transaction
  5. `DispatchWorker` processes each job asynchronously
  6. Each handler's `handle_event/2` callback is invoked

  ## Configuration Options

  - `:oban` - Oban instance module (default: `Oban`)
  - `:queue` - Oban queue name (default: `:events`)
  - `:max_attempts` - Maximum retry attempts (default: `3`)
  - `:priority` - Job priority, 0-3, lower is higher priority (default: `2`)

  ## API

  Using this module provides:
  - `emit/2` - Dispatch events to handlers via Oban jobs
  - `get_handlers!/1` - Get handlers for an event
  - `all_events/0` - List all registered events
  - `registered?/1` - Check if an event exists

  ## Handler Implementation

  Create handlers by implementing the `ObanEvents.Handler` behaviour:

      defmodule MyApp.EmailHandler do
        use ObanEvents.Handler

        @impl true
        def handle_event(:user_created, data) do
          %{"user_id" => user_id, "email" => email} = data
          # Send welcome email
          :ok
        end

        def handle_event(_event, _data), do: :ok
      end
  """

  @doc """
  Emit an event.

  Creates Oban jobs for all registered handlers of the given event.
  Should be called within a transaction to ensure atomicity.

  Accepts either:
  - `(event_name, data)`
  - `(event_name, data, metadata)`
  - `(%ObanEvents.Event{})`

  Returns `{:ok, jobs}` on success. Raises `ArgumentError` if event is not registered.
  """
  @callback emit(atom() | ObanEvents.Event.t(), map(), map()) :: {:ok, [Oban.Job.t()]}
  @callback emit(atom() | ObanEvents.Event.t(), map()) :: {:ok, [Oban.Job.t()]}
  @callback emit(atom() | ObanEvents.Event.t()) :: {:ok, [Oban.Job.t()]}

  @doc """
  Get all handler modules registered for a given event.
  """
  @callback get_handlers!(atom()) :: [module()]

  @doc """
  Get all registered event names.
  """
  @callback all_events() :: [atom()]

  @doc """
  Check if an event is registered.
  """
  @callback registered?(atom()) :: boolean()

  defmacro __using__(opts) do
    oban = Keyword.get(opts, :oban, Oban)
    queue = Keyword.get(opts, :queue, :events)
    max_attempts = Keyword.get(opts, :max_attempts, 3)
    priority = Keyword.get(opts, :priority, 2)

    quote do
      use ObanEvents.Registry

      @oban_instance unquote(oban)
      @oban_queue unquote(queue)
      @oban_max_attempts unquote(max_attempts)
      @oban_priority unquote(priority)

      @before_compile ObanEvents
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      alias ObanEvents.DispatchWorker

      @doc """
      Emit an event.

      Creates Oban jobs for all registered handlers of the given event.
      Should be called within a transaction to ensure atomicity.

      ## Return Values

      - `{:ok, jobs}` - Successfully created Oban jobs (list of `Oban.Job` structs)

      ## Parameters

      - `event_or_struct`: Atom representing the event (e.g., `:user_created`) or an `%ObanEvents.Event{}` struct
      - `data`: Map of event-specific data (atom or string keys both work, must be JSON-serializable)
      - `metadata`: Optional map of additional metadata (e.g., trace context, correlation id, actor, etc.)

      ## Examples

          # Within a transaction (recommended)
          MyApp.Repo.transaction(fn ->
            with {:ok, user} <- MyApp.Repo.insert(changeset),
                 {:ok, _jobs} <- #{inspect(__MODULE__)}.emit(:user_created, %{id: user.id}) do
              {:ok, user}
            end
          end)

          # With additional metadata
          #{inspect(__MODULE__)}.emit(:user_created, %{id: user.id}, %{trace_id: "xyz-123"})

          # With an Event struct
          event = ObanEvents.Event.new(:user_created, %{id: user.id}, %{trace_id: "xyz-123"})
          #{inspect(__MODULE__)}.emit(event)

      Note: Handlers always receive data with string keys, regardless of how you emit.

      ## Errors

      Raises `ArgumentError` if the event is not registered.
      """
      @spec emit(atom() | ObanEvents.Event.t(), map(), map()) :: {:ok, [Oban.Job.t()]}
      def emit(event_or_struct, data \\ %{}, metadata \\ %{})

      def emit(%ObanEvents.Event{name: event_name, data: data, metadata: metadata}, _data, _metadata)
          when is_atom(event_name) and is_map(data) and is_map(metadata) do
        emit(event_name, data, metadata)
      end

      def emit(event_name, data, metadata)
          when is_atom(event_name) and is_map(data) and is_map(metadata) do
        handlers = get_handlers!(event_name)

        jobs =
          Enum.map(handlers, fn handler_module ->
            job_args =
              %{
                event: Atom.to_string(event_name),
                handler: Atom.to_string(handler_module),
                data: data
              }

            job_args =
              if map_size(metadata) > 0 do
                Map.put(job_args, :metadata, metadata)
              else
                job_args
              end

            DispatchWorker.new(
              job_args,
              queue: @oban_queue,
              max_attempts: @oban_max_attempts,
              priority: @oban_priority
            )
          end)

        if jobs == [] do
          # No handlers registered, nothing to do
          {:ok, []}
        else
          # Insert all jobs in a single operation
          # If called within a transaction, these inserts are part of it
          # Oban.insert_all always returns a list of jobs
          {:ok, @oban_instance.insert_all(jobs)}
        end
      end
    end
  end
end
