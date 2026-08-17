defmodule ObanEvents.Event do
  @moduledoc """
  Struct representing an event and its metadata before it is dispatched.

  Every event emitted via `ObanEvents.emit/2` (or `emit/3`) is wrapped in an
  `ObanEvents.Event` struct before being turned into Oban job args. This
  attaches additional metadata to each event that is useful for
  observability and debugging, without changing the `data` payload that
  handlers receive:

  - `:id` - A unique identifier for this specific emission, generated with
    `Ecto.UUID.generate/0` unless explicitly provided.
  - `:emitted_at` - The UTC timestamp the event was created, generated with
    `DateTime.utc_now/0` unless explicitly provided.
  - `:metadata` - Any additional caller-supplied metadata (e.g.
    `:correlation_id`, `:source`), stored as a map.

  This metadata is included alongside `event`, `handler`, and `data` in the
  resulting Oban job args (under the `"metadata"` key), so it can be
  inspected via the Oban Web UI or queried directly from `oban_jobs`. It is
  not passed to `ObanEvents.Handler.handle_event/2`, which keeps the handler
  contract unchanged.
  """

  @enforce_keys [:name, :data]
  defstruct name: nil,
            data: %{},
            id: nil,
            emitted_at: nil,
            metadata: %{}

  @type t :: %__MODULE__{
          name: atom(),
          data: map(),
          id: String.t(),
          emitted_at: DateTime.t(),
          metadata: map()
        }

  @doc """
  Build a new `ObanEvents.Event` struct for the given event name and data.

  An `:id` and `:emitted_at` are generated automatically. Pass additional
  caller-supplied metadata (e.g. `:source`, `:correlation_id`) via the
  `metadata` argument.

  ## Examples

      iex> event = ObanEvents.Event.new(:user_created, %{user_id: 1})
      iex> event.name
      :user_created
      iex> is_binary(event.id)
      true

      iex> event = ObanEvents.Event.new(:user_created, %{user_id: 1}, %{source: "signup_form"})
      iex> event.metadata
      %{source: "signup_form"}
  """
  @spec new(atom(), map(), map()) :: t()
  def new(name, data, metadata \\ %{})
      when is_atom(name) and is_map(data) and is_map(metadata) do
    %__MODULE__{
      name: name,
      data: data,
      id: Ecto.UUID.generate(),
      emitted_at: DateTime.utc_now(),
      metadata: metadata
    }
  end

  @doc """
  Convert an `ObanEvents.Event` into the Oban job args map for a given
  handler module.

  The returned map is JSON-serializable and includes the event's metadata
  (event id, emission timestamp, and any caller-supplied metadata) under
  the `"metadata"` key.

  ## Examples

      iex> event = ObanEvents.Event.new(:user_created, %{user_id: 1})
      iex> args = ObanEvents.Event.to_job_args(event, MyApp.EmailHandler)
      iex> args["event"]
      "user_created"
      iex> args["handler"]
      "Elixir.MyApp.EmailHandler"
      iex> args["metadata"]["event_id"] == event.id
      true
  """
  @spec to_job_args(t(), module()) :: map()
  def to_job_args(%__MODULE__{} = event, handler_module) when is_atom(handler_module) do
    %{
      "event" => Atom.to_string(event.name),
      "handler" => Atom.to_string(handler_module),
      "data" => event.data,
      "metadata" =>
        Map.merge(stringify_keys(event.metadata), %{
          "event_id" => event.id,
          "emitted_at" => DateTime.to_iso8601(event.emitted_at)
        })
    }
  end

  defp stringify_keys(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
  end
end
