defmodule ObanEvents.Event do
  @moduledoc """
  An emitted event as received by a handler.

  Handlers receive the data passed to `emit/3` wrapped in this struct,
  together with metadata for deduplication, causation tracking, and
  correlation.

  ## Fields

  - `:data` - The event data passed to `emit/3`, always with string keys
  - `:event_id` - Generated once per `emit` call (UUIDv7) and shared by every
    handler job created by that call
  - `:idempotency_key` - Generated per handler job (UUIDv7). Stays the same
    across retries of that job, so it can be used for deduplication
  - `:causation_id` - Optional. The `event_id` of the event that caused this one
  - `:correlation_id` - Optional. Groups events that belong to the same
    business operation

  ## event_id

  Identifies a single emit. Pass it as `:causation_id` when a handler emits
  follow-up events:

      def handle_event(:user_created, %Event{event_id: event_id, data: data}) do
        MyApp.Events.emit(:welcome_email_requested, data, causation_id: event_id)
      end

  ## idempotency_key

  Unique per handler job and stable across retries, which makes it suitable
  for outbox tables or for passing to external APIs that deduplicate requests:

      def handle_event(:user_created, %Event{idempotency_key: key, data: data}) do
        %OutboxEmail{idempotency_key: key, user_id: data["user_id"]}
        |> MyApp.Repo.insert(on_conflict: :nothing, conflict_target: :idempotency_key)

        :ok
      end

  ## causation_id

  Links an event to the event that caused it, forming a chain:

      # user_registered          event_id: "evt-1", causation_id: nil
      # └─ welcome_email_sent    event_id: "evt-2", causation_id: "evt-1"
      #    └─ email_delivered    event_id: "evt-3", causation_id: "evt-2"

  ## correlation_id

  Groups every event emitted for one business operation, even when they are
  not causally linked:

      correlation_id = UUIDv7.generate()

      MyApp.Events.emit(:subscription_upgraded, data, correlation_id: correlation_id)
      MyApp.Events.emit(:payment_processed, data, correlation_id: correlation_id)

  Jobs enqueued before this metadata existed are still dispatched, with `nil`
  metadata fields.
  """

  @type t :: %__MODULE__{
          data: map(),
          event_id: String.t() | nil,
          idempotency_key: String.t() | nil,
          causation_id: String.t() | nil,
          correlation_id: String.t() | nil
        }

  @enforce_keys [:data]
  defstruct [
    :data,
    :event_id,
    :idempotency_key,
    :causation_id,
    :correlation_id
  ]
end
