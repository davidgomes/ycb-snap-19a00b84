defmodule ObanEvents.Handler do
  @moduledoc """
  Behaviour for event handlers.

  Event handlers process events asynchronously via Oban workers.
  Each handler implements `handle_event/2` and/or `handle_event/3`.

  See the [README](README.md) for architectural guidance and best practices.

  ## Implementing a Handler

      defmodule MyApp.UserHandler do
        use ObanEvents.Handler

        # Using handle_event/2
        @impl true
        def handle_event(:user_created, data) do
          %{"user_id" => user_id} = data
          # Process the event
          :ok
        end

        # Or using handle_event/3 to access metadata and the Event struct
        @impl true
        def handle_event(:user_created, data, %ObanEvents.Event{metadata: metadata}) do
          %{"user_id" => user_id} = data
          # Process event with metadata
          :ok
        end

        # Ignore other events
        def handle_event(_event, _data), do: :ok
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
  Handle an event with event name and payload data.

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
  Handle an event with event name, payload data, and the `ObanEvents.Event` struct.

  Optional callback for handlers that require event metadata, ID, timestamp,
  correlation ID, or causation ID.

  ## Parameters

  - `event_name`: Atom representing the event (e.g., `:user_created`)
  - `data`: Map containing event-specific data
  - `event`: `ObanEvents.Event` struct containing metadata and identifiers

  ## Return Values

  - `:ok` | `{:ok, any()}` - Success
  - `{:error, any()}` - Failure (will trigger retry)
  """
  @callback handle_event(event_name :: atom(), data :: map(), event :: ObanEvents.Event.t()) ::
              :ok | {:ok, any()} | {:error, any()}

  @optional_callbacks [handle_event: 2, handle_event: 3]

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour ObanEvents.Handler
    end
  end
end
