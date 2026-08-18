defmodule ObanEvents.Event do
  @moduledoc """
  Struct representing an event with additional metadata.

  ## Fields

  - `name` - The event name atom (e.g., `:user_created`)
  - `data` - Map containing event data payload
  - `metadata` - Map containing additional metadata (e.g., correlation_id, timestamp, user_id, etc.)
  - `timestamp` - DateTime when the event was created/emitted (defaults to UTC now)
  """

  @type t :: %__MODULE__{
          name: atom(),
          data: map(),
          metadata: map(),
          timestamp: DateTime.t() | nil
        }

  defstruct [:name, :data, metadata: %{}, timestamp: nil]

  @doc """
  Creates a new `ObanEvents.Event` struct.

  ## Examples

      iex> ObanEvents.Event.new(:user_created, %{user_id: 123})
      %ObanEvents.Event{name: :user_created, data: %{user_id: 123}, metadata: %{}, timestamp: ...}

      iex> ObanEvents.Event.new(:user_created, %{user_id: 123}, %{trace_id: "abc-123"})
      %ObanEvents.Event{name: :user_created, data: %{user_id: 123}, metadata: %{trace_id: "abc-123"}, timestamp: ...}
  """
  @spec new(atom(), map(), map()) :: t()
  def new(name, data \\ %{}, metadata \\ %{}) when is_atom(name) and is_map(data) and is_map(metadata) do
    %__MODULE__{
      name: name,
      data: data,
      metadata: metadata,
      timestamp: DateTime.utc_now()
    }
  end
end
