defmodule ObanEvents.Event do
  @moduledoc """
  Struct representing an event before it is dispatched to handlers.

  In addition to the event `:name` and `:data` payload, `ObanEvents.Event`
  carries additional metadata useful for observability and debugging:

  - `:metadata` - a free-form map of contextual information (e.g. `actor_id`,
    `trace_id`, `source`) that is not part of the event's business data
  - `:emitted_at` - the `DateTime` (UTC) the event was created

  Metadata is not delivered to handlers directly (handlers still implement
  `handle_event/2`); it is persisted alongside the job args so it can be
  inspected via the Oban Web UI or the database for observability and
  debugging.

  ## Example

      iex> event = ObanEvents.Event.new(:user_created, %{"user_id" => 1}, metadata: %{source: "signup_form"})
      iex> event.name
      :user_created
      iex> event.metadata
      %{source: "signup_form"}
  """

  @enforce_keys [:name, :data]
  defstruct name: nil, data: %{}, metadata: %{}, emitted_at: nil

  @type t :: %__MODULE__{
          name: atom(),
          data: map(),
          metadata: map(),
          emitted_at: DateTime.t()
        }

  @doc """
  Build a new event.

  ## Options

  - `:metadata` - a map of additional metadata to attach to the event (default: `%{}`)
  - `:emitted_at` - override the emission timestamp (default: `DateTime.utc_now/0`)

  ## Examples

      iex> ObanEvents.Event.new(:user_created, %{"user_id" => 1}).name
      :user_created

      iex> ObanEvents.Event.new(:user_created, %{}, metadata: %{source: "api"}).metadata
      %{source: "api"}
  """
  @spec new(atom(), map(), keyword()) :: t()
  def new(name, data, opts \\ []) when is_atom(name) and is_map(data) do
    %__MODULE__{
      name: name,
      data: data,
      metadata: Keyword.get(opts, :metadata, %{}),
      emitted_at: Keyword.get(opts, :emitted_at, DateTime.utc_now())
    }
  end
end
