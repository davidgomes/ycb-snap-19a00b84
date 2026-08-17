defmodule ObanEvents.Event do
  @moduledoc """
  Struct representing an event before it is dispatched to Oban.

  In addition to the event `name` and `data`, every event carries a small
  set of metadata that's useful for tracing and debugging:

  - `:id` - A unique identifier for this specific emission (UUID)
  - `:emitted_at` - The `DateTime` the event was created
  - `:metadata` - A free-form map for caller-supplied context (e.g.
    `%{source: "web", actor_id: user.id}`)

  This struct is built internally by `emit/2`/`emit/3` and is not required
  to be constructed by consumers directly, but `new/3` is exposed for use in
  tests and tooling.
  """

  @enforce_keys [:name, :data]
  defstruct [:name, :data, :id, :emitted_at, metadata: %{}]

  @type t :: %__MODULE__{
          name: atom(),
          data: map(),
          id: String.t(),
          emitted_at: DateTime.t(),
          metadata: map()
        }

  @doc """
  Build a new `ObanEvents.Event` struct.

  Generates a unique `:id` and stamps `:emitted_at` with the current UTC
  time. `metadata` defaults to an empty map when not provided.

  ## Examples

      iex> event = ObanEvents.Event.new(:user_created, %{"user_id" => 1})
      iex> event.name
      :user_created
      iex> event.data
      %{"user_id" => 1}
  """
  @spec new(atom(), map(), map()) :: t()
  def new(name, data, metadata \\ %{}) when is_atom(name) and is_map(data) and is_map(metadata) do
    %__MODULE__{
      name: name,
      data: data,
      id: Ecto.UUID.generate(),
      emitted_at: DateTime.utc_now(),
      metadata: metadata
    }
  end
end
