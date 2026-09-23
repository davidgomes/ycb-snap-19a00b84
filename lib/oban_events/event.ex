defmodule ObanEvents.Event do
  @moduledoc """
  Container for event data with metadata.

  Handlers receive their event data wrapped in this struct, together with
  metadata for deduplication, causation tracking, and correlation.

  ## Fields

  - `:data` - The event data (map with string keys)
  - `:event_id` - Unique per emit. Shared by all handlers of the same emit.
  - `:idempotency_key` - Unique per handler job. Stable across retries of that job.
  - `:causation_id` - Optional. The `event_id` of the parent event that caused this one.
  - `:correlation_id` - Optional. Groups related events from the same business operation.

  `event_id` and `idempotency_key` are generated automatically by `emit/3`
  as UUIDv7 strings. `causation_id` and `correlation_id` are passed as
  options to `emit/3`.

  ## event_id

  Identifies the emit itself. Pass it as `causation_id` when emitting
  child events to build event chains:

      def handle_event(:user_created, %Event{event_id: id, data: data}) do
        MyApp.Events.emit(:welcome_email_requested, data, causation_id: id)
      end

  ## idempotency_key

  Unique for each handler job and preserved when Oban retries the job.
  Use it to deduplicate side effects, e.g. with an outbox table:

      def handle_event(:user_created, %Event{idempotency_key: key, data: data}) do
        MyApp.Repo.insert(
          %OutboxEmail{idempotency_key: key, user_id: data["user_id"]},
          on_conflict: :nothing,
          conflict_target: :idempotency_key
        )

        :ok
      end

  ## causation_id

  The `event_id` of the event that caused this emit:

      # user_registered        (event_id: "evt-1", causation_id: nil)
      # └─> welcome_email_sent (event_id: "evt-2", causation_id: "evt-1")

  ## correlation_id

  Groups every event emitted as part of one business operation:

      correlation_id = ObanEvents.Event.generate_id()

      MyApp.Events.emit(:subscription_upgraded, data, correlation_id: correlation_id)
      MyApp.Events.emit(:payment_processed, data, correlation_id: correlation_id)
  """

  @type t :: %__MODULE__{
          data: map(),
          event_id: String.t(),
          idempotency_key: String.t(),
          causation_id: String.t() | nil,
          correlation_id: String.t() | nil
        }

  defstruct [
    :data,
    :event_id,
    :idempotency_key,
    :causation_id,
    :correlation_id
  ]

  @doc """
  Generates a UUIDv7 string.

  UUIDv7 values are time-ordered, so IDs sort by creation time.
  Used for `event_id` and `idempotency_key`, and handy for creating
  a `correlation_id`.

  ## Examples

      iex> ObanEvents.Event.generate_id()
      "01933b7e-8a3f-7f6f-9e42-6c8f3a0b2d1e"
  """
  @spec generate_id() :: String.t()
  def generate_id do
    timestamp = System.system_time(:millisecond)
    <<rand_a::12, rand_b::62, _::6>> = :crypto.strong_rand_bytes(10)

    <<a::binary-8, b::binary-4, c::binary-4, d::binary-4, e::binary-12>> =
      Base.encode16(<<timestamp::48, 7::4, rand_a::12, 2::2, rand_b::62>>, case: :lower)

    "#{a}-#{b}-#{c}-#{d}-#{e}"
  end
end
