defmodule ObanEvents.Event do
  @moduledoc """
  Struct passed to handlers for every dispatched event.

  Wraps the emitted event data together with metadata for deduplication,
  causation tracking, and correlation.

  ## Fields

  - `:data` - The emitted event data (map with string keys)
  - `:event_id` - Unique per emit. Shared by all handler jobs created by the same `emit` call.
  - `:idempotency_key` - Unique per handler job. Stable across retries of that job.
  - `:causation_id` - Optional. The `event_id` of the parent event that caused this emit.
  - `:correlation_id` - Optional. Groups related events belonging to the same business operation.

  ## event_id (auto-generated)

  Generated once per `emit` call. Pass it as `causation_id` when emitting
  child events to build event chains:

      def handle_event(:user_created, %Event{event_id: id, data: data}) do
        MyApp.Events.emit(:send_welcome_email, data, causation_id: id)
      end

  ## idempotency_key (auto-generated)

  Generated once per handler job and preserved across Oban retries. Use it to
  deduplicate side effects (e.g. outbox inserts with `on_conflict: :nothing`).

  ## causation_id (user-provided, optional)

  The `event_id` that caused this emit:

      # user_registered     (event_id: "evt-001", causation_id: nil)
      # └─> send_welcome_email (event_id: "evt-002", causation_id: "evt-001")

  ## correlation_id (user-provided, optional)

  Groups related events from a single business operation across multiple emits:

      correlation_id = Ecto.UUID.generate()
      MyApp.Events.emit(:order_placed, data, correlation_id: correlation_id)
      MyApp.Events.emit(:payment_processed, data, correlation_id: correlation_id)
  """

  @type t :: %__MODULE__{
          data: map(),
          event_id: String.t() | nil,
          idempotency_key: String.t() | nil,
          causation_id: String.t() | nil,
          correlation_id: String.t() | nil
        }

  defstruct data: %{},
            event_id: nil,
            idempotency_key: nil,
            causation_id: nil,
            correlation_id: nil
end
