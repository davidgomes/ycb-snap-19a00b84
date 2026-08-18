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
  - `emit/3` - Dispatch events with metadata
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

  ## Event Metadata

  Events carry metadata beyond their payload: a unique event id, the emit time
  and any metadata passed to `emit/3`. Handlers that implement `handle_event/3`
  receive it as an `ObanEvents.Event` struct:

      MyApp.Events.emit(:user_created, %{user_id: user.id}, meta: %{actor_id: actor.id})

      defmodule MyApp.AuditHandler do
        use ObanEvents.Handler

        @impl true
        def handle_event(name, data, %ObanEvents.Event{} = event) do
          MyApp.Audit.record(name, data, event_id: event.id, actor_id: event.meta["actor_id"])
        end
      end

  ## Testing

  `ObanEvents.Testing` provides helpers to assert on emitted events and to run
  handlers without going through the database.
  """

  @doc """
  Emit an event.

  Creates Oban jobs for all registered handlers of the given event.
  Should be called within a transaction to ensure atomicity.

  Returns `{:ok, jobs}` on success. Raises `ArgumentError` if event is not registered.
  """
  @callback emit(atom(), map()) :: {:ok, [Oban.Job.t()]}

  @doc """
  Emit an event with metadata.

  Accepts the metadata options of `ObanEvents.Event.new/3`: `:meta`, `:id` and
  `:emitted_at`.
  """
  @callback emit(atom(), map(), keyword()) :: {:ok, [Oban.Job.t()]}

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

      - `event_name`: Atom representing the event (e.g., `:user_created`)
      - `data`: Map of event-specific data (atom or string keys both work, must be JSON-serializable)

      ## Examples

          # Within a transaction (recommended)
          MyApp.Repo.transaction(fn ->
            with {:ok, user} <- MyApp.Repo.insert(changeset),
                 {:ok, _jobs} <- #{inspect(__MODULE__)}.emit(:user_created, %{id: user.id}) do
              {:ok, user}
            end
          end)

          # With atom keys (recommended for readability)
          #{inspect(__MODULE__)}.emit(:user_updated, %{
            user_id: user.id,
            old_email: "old@example.com",
            new_email: "new@example.com"
          })

          # With string keys (also valid)
          #{inspect(__MODULE__)}.emit(:user_updated, %{
            "user_id" => user.id,
            "new_email" => "new@example.com"
          })

      Note: Handlers always receive data with string keys, regardless of how you emit.

      ## Errors

      Raises `ArgumentError` if the event is not registered.
      """
      @spec emit(atom(), map()) :: {:ok, [Oban.Job.t()]}
      def emit(event_name, data) when is_atom(event_name) and is_map(data) do
        emit(event_name, data, [])
      end

      @doc """
      Emit an event with metadata.

      Same as `emit/2`, with metadata attached to the event. All handler jobs
      created by a single call share the same event id, which makes it possible
      to trace one emit across its handlers.

      ## Options

      - `:meta` - metadata map carried alongside the payload, e.g. the actor or
        request that caused the event (must be JSON-serializable)
      - `:id` - unique event id (default: a generated UUID)
      - `:emitted_at` - `DateTime` the event was emitted (default: `DateTime.utc_now/0`)

      Metadata is available to handlers that implement `handle_event/3` via the
      `ObanEvents.Event` struct.

      ## Examples

          #{inspect(__MODULE__)}.emit(:user_created, %{user_id: user.id},
            meta: %{actor_id: actor.id, request_id: Logger.metadata()[:request_id]}
          )

      ## Errors

      Raises `ArgumentError` if the event is not registered or if the metadata
      options are invalid.
      """
      @spec emit(atom(), map(), keyword()) :: {:ok, [Oban.Job.t()]}
      def emit(event_name, data, opts)
          when is_atom(event_name) and is_map(data) and is_list(opts) do
        handlers = get_handlers!(event_name)
        event = ObanEvents.Event.new(event_name, data, opts)

        jobs =
          Enum.map(handlers, fn handler_module ->
            event
            |> ObanEvents.Event.for_handler(handler_module)
            |> ObanEvents.Event.to_args()
            |> DispatchWorker.new(
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
