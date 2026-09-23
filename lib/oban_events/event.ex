defmodule ObanEvents.Event do
  @moduledoc """
  The event delivered to handlers: your data plus metadata for tracing,
  deduplication, and correlation.

  Handlers receive an `%ObanEvents.Event{}` as the second argument of
  `c:ObanEvents.Handler.handle_event/2`:

      alias ObanEvents.Event

      def handle_event(:user_created, %Event{data: data, event_id: event_id}) do
        %{"user_id" => user_id} = data
        # ...
        :ok
      end

  ## Fields

  - `:data` - The map passed to `emit`. Keys are always strings, because job
    args are serialized to JSON.
  - `:event_id` - Generated once per `emit` call. Every handler job created by
    the same emit shares this value.
  - `:idempotency_key` - Generated once per handler job. It stays the same when
    Oban retries the job, so it can be used to deduplicate side effects.
  - `:causation_id` - Optional. The `event_id` of the event that caused this
    one, set via the `:causation_id` option of `emit/3`.
  - `:correlation_id` - Optional. Groups events emitted by the same business
    operation, set via the `:correlation_id` option of `emit/3`.

  ## Building event chains

  Pass the current `event_id` as the `:causation_id` of events emitted from a
  handler to record why they happened, and forward the `correlation_id` so the
  whole chain can be traced back to one operation:

      def handle_event(:user_created, %Event{} = event) do
        MyApp.Events.emit(:welcome_email_requested, event.data,
          causation_id: event.event_id,
          correlation_id: event.correlation_id
        )

        :ok
      end

  ## Deduplicating side effects

  Handlers can be executed more than once (retries, restarts, node failures).
  Use `idempotency_key` with a unique constraint to make side effects safe to
  repeat:

      def handle_event(:user_created, %Event{data: data, idempotency_key: key}) do
        MyApp.Repo.insert(
          %MyApp.OutboxEmail{idempotency_key: key, user_id: data["user_id"]},
          on_conflict: :nothing,
          conflict_target: :idempotency_key
        )

        :ok
      end
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
