defmodule ObanEvents.Event do
  @moduledoc """
  The event passed to `c:ObanEvents.Handler.handle_event/2`.

  Wraps the emitted data together with metadata for deduplication, tracing,
  and correlation.

  ## Fields

  - `:data` - The emitted data. Keys are always strings, because the data is
    serialized to JSON when the job is persisted.
  - `:event_id` - UUIDv7 generated once per `emit`. Every handler invoked for
    the same emit receives the same `event_id`.
  - `:idempotency_key` - UUIDv7 generated once per handler job. It is stable
    across retries of that job, so it can be used to deduplicate side effects.
  - `:causation_id` - Optional. The `event_id` of the event that caused this
    one to be emitted.
  - `:correlation_id` - Optional. Groups all events belonging to the same
    business operation.

  ## Deduplicating side effects

  Handlers may run more than once for the same job (e.g. after a crash or a
  failed attempt). Use `idempotency_key` to make side effects safe to repeat:

      def handle_event(:order_placed, %Event{data: data, idempotency_key: key}) do
        %OutboxEmail{idempotency_key: key, order_id: data["order_id"]}
        |> Repo.insert(on_conflict: :nothing, conflict_target: :idempotency_key)

        :ok
      end

  ## Building event chains

  Pass the current `event_id` as `:causation_id` when a handler emits a
  follow-up event:

      def handle_event(:user_registered, %Event{event_id: event_id, data: data}) do
        MyApp.Events.emit(:welcome_email_requested, data, causation_id: event_id)
      end

  This produces a traceable chain:

      user_registered               (event_id: "evt-1", causation_id: nil)
      └─ welcome_email_requested    (event_id: "evt-2", causation_id: "evt-1")

  ## Correlating a business operation

  Use the same `:correlation_id` for every event emitted as part of one
  operation, and propagate it from handlers that emit further events:

      correlation_id = UUIDv7.generate()

      MyApp.Events.emit(:order_placed, %{order_id: order.id}, correlation_id: correlation_id)
      MyApp.Events.emit(:payment_captured, %{order_id: order.id}, correlation_id: correlation_id)
  """

  @enforce_keys [:data, :event_id, :idempotency_key]
  defstruct [:data, :event_id, :idempotency_key, :causation_id, :correlation_id]

  @type t :: %__MODULE__{
          data: map(),
          event_id: String.t(),
          idempotency_key: String.t(),
          causation_id: String.t() | nil,
          correlation_id: String.t() | nil
        }
end
