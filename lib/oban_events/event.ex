defmodule ObanEvents.Event do
  @moduledoc """
  An emitted event, as delivered to handlers.

  Every call to `emit/3` builds one event that is shared by all handlers
  registered for it, so every handler job for the same emission sees the
  same `event_id`, `emitted_at`, and metadata.

  ## Fields

  - `:event_id` - Unique identifier (UUID) of this emission
  - `:name` - Event name atom (e.g., `:user_created`)
  - `:data` - Event payload, always with string keys
  - `:metadata` - Arbitrary, JSON-serializable map with string keys
    (e.g., `%{"actor_id" => 123, "source" => "api"}`)
  - `:causation_id` - `event_id` of the event that directly caused this one, if any
  - `:correlation_id` - Identifier shared by every event in the same chain.
    Defaults to the event's own `event_id` when it starts a new chain.
  - `:emitted_at` - UTC `DateTime` at which the event was emitted

  Jobs enqueued by versions of ObanEvents that did not record metadata are
  still delivered as events, with `nil` for the missing identifiers and
  timestamps and an empty `metadata` map.
  """

  @enforce_keys [:name, :data]
  defstruct [
    :event_id,
    :name,
    :causation_id,
    :correlation_id,
    :emitted_at,
    data: %{},
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          event_id: String.t() | nil,
          name: atom(),
          data: map(),
          metadata: map(),
          causation_id: String.t() | nil,
          correlation_id: String.t() | nil,
          emitted_at: DateTime.t() | nil
        }

  @type option ::
          {:event_id, String.t()}
          | {:metadata, map()}
          | {:causation_id, String.t() | nil}
          | {:correlation_id, String.t() | nil}
          | {:caused_by, t()}
          | {:emitted_at, DateTime.t()}

  @doc """
  Build a new event.

  `data` and `metadata` keys are normalized to strings, matching what handlers
  receive after the event has been round-tripped through the database.

  ## Options

  - `:metadata` - Map of additional metadata (default: `%{}`)
  - `:caused_by` - Parent `%ObanEvents.Event{}`. Sets `causation_id` to the
    parent's `event_id` and inherits its `correlation_id`.
  - `:causation_id` - Explicit causation id (overrides `:caused_by`)
  - `:correlation_id` - Explicit correlation id (overrides `:caused_by`)
  - `:event_id` - Explicit event id (default: a generated UUID)
  - `:emitted_at` - Explicit timestamp (default: `DateTime.utc_now/0`)
  """
  @spec new(atom(), map(), [option()]) :: t()
  def new(name, data, opts \\ []) when is_atom(name) and is_map(data) and is_list(opts) do
    event_id = Keyword.get_lazy(opts, :event_id, &Ecto.UUID.generate/0)
    parent = Keyword.get(opts, :caused_by)
    metadata = Keyword.get(opts, :metadata, %{})

    unless is_map(metadata) do
      raise ArgumentError, "expected :metadata to be a map, got: #{inspect(metadata)}"
    end

    %__MODULE__{
      event_id: event_id,
      name: name,
      data: stringify_keys(data),
      metadata: stringify_keys(metadata),
      causation_id: Keyword.get_lazy(opts, :causation_id, fn -> parent_id(parent) end),
      correlation_id:
        Keyword.get_lazy(opts, :correlation_id, fn -> parent_correlation_id(parent) end) ||
          event_id,
      emitted_at: Keyword.get_lazy(opts, :emitted_at, &utc_now/0)
    }
  end

  @doc false
  @spec to_args(t(), module()) :: map()
  def to_args(%__MODULE__{} = event, handler) when is_atom(handler) do
    %{
      "event" => Atom.to_string(event.name),
      "handler" => Atom.to_string(handler),
      "data" => event.data,
      "event_id" => event.event_id,
      "metadata" => event.metadata,
      "causation_id" => event.causation_id,
      "correlation_id" => event.correlation_id,
      "emitted_at" => event.emitted_at && DateTime.to_iso8601(event.emitted_at)
    }
  end

  @doc false
  @spec from_args(atom(), map()) :: t()
  def from_args(name, %{"data" => data} = args) when is_atom(name) do
    %__MODULE__{
      event_id: args["event_id"],
      name: name,
      data: data,
      metadata: args["metadata"] || %{},
      causation_id: args["causation_id"],
      correlation_id: args["correlation_id"],
      emitted_at: parse_datetime(args["emitted_at"])
    }
  end

  defp parent_id(%__MODULE__{event_id: id}), do: id
  defp parent_id(nil), do: nil

  defp parent_correlation_id(%__MODULE__{correlation_id: id, event_id: event_id}),
    do: id || event_id

  defp parent_correlation_id(nil), do: nil

  defp utc_now, do: DateTime.utc_now() |> DateTime.truncate(:microsecond)

  defp parse_datetime(nil), do: nil

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      {:error, _} -> nil
    end
  end

  defp stringify_keys(%{__struct__: _} = struct), do: struct

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {to_key(key), stringify_keys(value)} end)
  end

  defp stringify_keys(list) when is_list(list), do: Enum.map(list, &stringify_keys/1)
  defp stringify_keys(value), do: value

  defp to_key(key) when is_atom(key), do: Atom.to_string(key)
  defp to_key(key), do: key
end
