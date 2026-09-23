defmodule ObanEvents.Event do
  @moduledoc """
  Struct passed to handlers, wrapping the event data with metadata.

  ## Fields

  - `:name` - Event name atom (e.g., `:user_created`)
  - `:data` - Event-specific data map (string keys)
  - `:event_id` - Unique identifier shared by all handler jobs of one emit
  - `:emitted_at` - `DateTime` when the event was emitted
  - `:metadata` - Additional user-supplied metadata map (string keys)
  - `:job_id` - Oban job id processing this event (if any)
  - `:attempt` - Current Oban attempt number (if any)
  """

  @type t :: %__MODULE__{
          name: atom(),
          data: map(),
          event_id: String.t() | nil,
          emitted_at: DateTime.t() | nil,
          metadata: map(),
          job_id: integer() | nil,
          attempt: pos_integer() | nil
        }

  defstruct name: nil,
            data: %{},
            event_id: nil,
            emitted_at: nil,
            metadata: %{},
            job_id: nil,
            attempt: nil

  @doc false
  def generate_id do
    <<a::48, _::4, b::12, _::2, c::62>> = :crypto.strong_rand_bytes(16)

    <<a::48, 4::4, b::12, 2::2, c::62>>
    |> Base.encode16(case: :lower)
    |> then(fn <<p1::binary-8, p2::binary-4, p3::binary-4, p4::binary-4, p5::binary-12>> ->
      Enum.join([p1, p2, p3, p4, p5], "-")
    end)
  end

  @doc false
  def parse_datetime(nil), do: nil

  def parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _offset} -> dt
      _ -> nil
    end
  end
end
