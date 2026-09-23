defmodule ObanEvents.Event do
  @moduledoc """
  Container for event data with metadata.

  Handlers receive event data wrapped in this struct, which includes
  the user's event data plus metadata for deduplication, causation tracking,
  and correlation.

  ## Fields

  - `:data` - The user's event data (map)
  - `:event_id` - Unique per emit. Identifies this specific emit (shared by all handlers).
  - `:idempotency_key` - Unique per job. Use for deduplication/outbox patterns.
  - `:causation_id` - Optional. The event_id of the parent emit that caused this one.
  - `:correlation_id` - Optional. Groups related events from the same business operation.
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

  Used for `event_id`, `idempotency_key`, and caller-supplied correlation ids.
  """
  @spec generate_id() :: String.t()
  def generate_id do
    unix_ms = System.system_time(:millisecond)
    <<rand_a::12, rand_b::62, _::6>> = :crypto.strong_rand_bytes(10)

    <<unix_ms::48, 7::4, rand_a::12, 2::2, rand_b::62>>
    |> Base.encode16(case: :lower)
    |> format_uuid()
  end

  defp format_uuid(
         <<a::binary-size(8), b::binary-size(4), c::binary-size(4), d::binary-size(4),
           e::binary-size(12)>>
       ) do
    a <> "-" <> b <> "-" <> c <> "-" <> d <> "-" <> e
  end
end
