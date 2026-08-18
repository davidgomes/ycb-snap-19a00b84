defmodule ObanEvents.Handler do
  @moduledoc """
  Behaviour for event handlers.

  Event handlers process events asynchronously via Oban workers.
  Each handler implements `handle_event/2` or `handle_event/3`.

  See the [README](README.md) for architectural guidance and best practices.

  ## Implementing a Handler

      defmodule MyApp.UserHandler do
        use ObanEvents.Handler

        @impl true
        def handle_event(:user_created, data) do
          %{"user_id" => user_id} = data
          # Process the event
          :ok
        end

        # Ignore other events
        def handle_event(_event, _data), do: :ok
      end

  ## Accessing Event Metadata

  Handlers that need the event metadata implement `handle_event/3` instead,
  which receives the `ObanEvents.Event` struct as the third argument. A handler
  implements either callback, `handle_event/3` takes precedence when both exist.

      defmodule MyApp.AuditHandler do
        use ObanEvents.Handler

        @impl true
        def handle_event(name, data, %ObanEvents.Event{} = event) do
          MyApp.Audit.record(name, data,
            event_id: event.id,
            actor_id: event.meta["actor_id"],
            emitted_at: event.emitted_at,
            attempt: event.attempt
          )
        end
      end

  ## Return Values

  Handlers should return:
  - `:ok` - Event processed successfully
  - `{:ok, result}` - Event processed successfully with a result
  - `{:error, reason}` - Event processing failed (will trigger Oban retry)

  ## Error Handling

  If a handler returns `{:error, reason}` or raises an exception, Oban will
  automatically retry the job according to the worker's retry configuration.

  ## Best Practices

  1. Keep handlers focused on a single concern
  2. Make handlers idempotent (safe to run multiple times)
  3. Pattern match on specific events, ignore others
  4. Log important actions for debugging
  5. Return errors for retriable failures, :ok for non-retriable ones
  """

  @doc """
  Handle an event.

  Receives the event name (atom) and event-specific data (map).
  Should process the event and return an ok/error tuple.

  ## Parameters

  - `event_name`: Atom representing the event (e.g., `:user_created`)
  - `data`: Map containing event-specific data

  ## Return Values

  - `:ok` | `{:ok, any()}` - Success
  - `{:error, any()}` - Failure (will trigger retry)
  """
  @callback handle_event(event_name :: atom(), data :: map()) ::
              :ok | {:ok, any()} | {:error, any()}

  @doc """
  Handle an event with access to its metadata.

  Same as `c:handle_event/2`, but also receives the `ObanEvents.Event` struct
  describing the event: its id, metadata, emit time and current Oban attempt.

  When a handler exports this callback it is used instead of `c:handle_event/2`.

  ## Parameters

  - `event_name`: Atom representing the event (e.g., `:user_created`)
  - `data`: Map containing event-specific data
  - `event`: `ObanEvents.Event` struct with the event metadata

  ## Return Values

  - `:ok` | `{:ok, any()}` - Success
  - `{:error, any()}` - Failure (will trigger retry)
  """
  @callback handle_event(event_name :: atom(), data :: map(), event :: ObanEvents.Event.t()) ::
              :ok | {:ok, any()} | {:error, any()}

  @optional_callbacks handle_event: 2, handle_event: 3

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour ObanEvents.Handler

      @before_compile ObanEvents.Handler
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    defines_event_callback? =
      Module.defines?(env.module, {:handle_event, 2}) or
        Module.defines?(env.module, {:handle_event, 3})

    unless defines_event_callback? do
      raise CompileError,
        file: env.file,
        line: env.line,
        description:
          "Missing handle_event callback in #{inspect(env.module)}. " <>
            "Handlers must define handle_event/2, or handle_event/3 to also receive the ObanEvents.Event struct."
    end

    quote(do: nil)
  end
end
