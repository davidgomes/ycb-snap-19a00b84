defmodule ObanEvents.Handler do
  @moduledoc """
  Behaviour for event handlers.

  Event handlers process events asynchronously via Oban workers.
  Each handler implements a single callback: `handle_event/2`.

  See the [README](README.md) for architectural guidance and best practices.

  ## Implementing a Handler

      defmodule MyApp.UserHandler do
        use ObanEvents.Handler

        @impl true
        def handle_event(:user_created, %Event{data: data, idempotency_key: key}) do
          %{"user_id" => user_id} = data
          # Process the event, using `key` to deduplicate side effects
          :ok
        end

        # Ignore other events
        def handle_event(_event_name, _event), do: :ok
      end

  `use ObanEvents.Handler` aliases `ObanEvents.Event`, so `%Event{}` can be used
  directly in pattern matches.

  ## Event Metadata

  Handlers receive an `ObanEvents.Event` struct with these fields:

  - `data` - The emitted data (map with string keys)
  - `event_id` - Unique ID of the emit, shared by all handlers of that emit
  - `idempotency_key` - Unique ID of this handler's job, stable across retries
  - `causation_id` - Optional `event_id` of the event that caused this one
  - `correlation_id` - Optional ID grouping the events of one business operation

  See `ObanEvents.Event` for details on each field.

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
  2. Make handlers idempotent (safe to run multiple times), e.g. using `idempotency_key`
  3. Pattern match on specific events, ignore others
  4. Pass `event_id` as `:causation_id` when emitting follow-up events
  5. Log important actions for debugging
  6. Return errors for retriable failures, :ok for non-retriable ones
  """

  @doc """
  Handle an event.

  Receives the event name (atom) and an `ObanEvents.Event` struct containing
  the event data and metadata. Should process the event and return an
  ok/error tuple.

  ## Parameters

  - `event_name`: Atom representing the event (e.g., `:user_created`)
  - `event`: `ObanEvents.Event` struct with the data and metadata

  ## Return Values

  - `:ok` | `{:ok, any()}` - Success
  - `{:error, any()}` - Failure (will trigger retry)
  """
  @callback handle_event(event_name :: atom(), event :: ObanEvents.Event.t()) ::
              :ok | {:ok, any()} | {:error, any()}

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour ObanEvents.Handler

      alias ObanEvents.Event
    end
  end
end
