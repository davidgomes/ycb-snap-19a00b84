defmodule ObanEvents.Event do
  @moduledoc """
  Event struct representing an event in ObanEvents.

  Encapsulates event name, data payload, and metadata such as event ID,
  timestamp, correlation ID, causation ID, and custom metadata.

  ## Fields

  - `id` - Unique event identifier (binary UUID string). Generated automatically if not provided.
  - `name` - Atom representing the event name (e.g. `:user_created`).
  - `data` - Map containing event-specific data payload.
  - `timestamp` - `DateTime` representing when the event occurred (defaults to UTC now in ISO8601 when serialized).
  - `correlation_id` - Optional binary string or term tracking the flow across multiple events.
  - `causation_id` - Optional binary string or term tracking the parent event/command ID.
  - `metadata` - Map of additional contextual metadata (e.g. actor, tenant, IP, request_id).
  """

  @enforce_keys [:name]
  defstruct [
    :id,
    :name,
    :data,
    :timestamp,
    :correlation_id,
    :causation_id,
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: atom(),
          data: map() | nil,
          timestamp: DateTime.t() | String.t() | nil,
          correlation_id: String.t() | nil,
          causation_id: String.t() | nil,
          metadata: map()
        }

  @doc """
  Builds a new `ObanEvents.Event` struct from an attributes map or keyword list.

  ## Examples

      ObanEvents.Event.new(%{
        name: :user_created,
        data: %{user_id: 123},
        correlation_id: "corr-123",
        metadata: %{tenant_id: "acme"}
      })
  """
  @spec new(map() | keyword()) :: t()
  def new(attrs) when is_list(attrs) do
    new(Map.new(attrs))
  end

  def new(attrs) when is_map(attrs) do
    name = Map.get(attrs, :name) || Map.get(attrs, "name")
    data = Map.get(attrs, :data) || Map.get(attrs, "data") || %{}
    opts = Map.drop(attrs, [:name, "name", :data, "data"])

    name_atom = if is_binary(name), do: String.to_atom(name), else: name
    new(name_atom, data, opts)
  end

  @doc """
  Builds a new `ObanEvents.Event` struct with event name, data payload, and optional metadata options.

  ## Examples

      # Simple event with data
      ObanEvents.Event.new(:user_created, %{user_id: 123, email: "user@example.com"})

      # Event with options (metadata, correlation_id, etc.)
      ObanEvents.Event.new(:user_created, %{user_id: 123},
        correlation_id: "corr-123",
        causation_id: "cause-456",
        metadata: %{actor_id: 1, ip: "127.0.0.1"}
      )
  """
  @spec new(atom(), map(), keyword() | map()) :: t()
  def new(name, data, opts \\ [])

  def new(name, data, opts) when is_atom(name) and is_map(data) and is_list(opts) do
    new(name, data, Map.new(opts))
  end

  def new(name, data, opts) when is_atom(name) and is_map(data) and is_map(opts) do
    id = Map.get(opts, :id) || Map.get(opts, "id") || generate_id()
    timestamp = Map.get(opts, :timestamp) || Map.get(opts, "timestamp") || DateTime.utc_now()
    correlation_id = Map.get(opts, :correlation_id) || Map.get(opts, "correlation_id")
    causation_id = Map.get(opts, :causation_id) || Map.get(opts, "causation_id")
    metadata = Map.get(opts, :metadata) || Map.get(opts, "metadata") || %{}

    %__MODULE__{
      id: id,
      name: name,
      data: data,
      timestamp: timestamp,
      correlation_id: correlation_id,
      causation_id: causation_id,
      metadata: metadata
    }
  end

  @doc """
  Converts an `ObanEvents.Event` struct into a map suitable for Oban job arguments (JSON serialization).
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = event) do
    %{
      "id" => event.id,
      "event" => to_string(event.name),
      "data" => event.data,
      "timestamp" => format_timestamp(event.timestamp),
      "correlation_id" => event.correlation_id,
      "causation_id" => event.causation_id,
      "metadata" => event.metadata
    }
  end

  @doc """
  Constructs an `ObanEvents.Event` struct from job args map.
  """
  @spec from_map(map()) :: t()
  def from_map(args) when is_map(args) do
    name_str = Map.get(args, "event") || Map.get(args, :event)
    name = if is_binary(name_str), do: String.to_existing_atom(name_str), else: name_str

    %__MODULE__{
      id: Map.get(args, "id") || Map.get(args, :id),
      name: name,
      data: Map.get(args, "data") || Map.get(args, :data) || %{},
      timestamp: parse_timestamp(Map.get(args, "timestamp") || Map.get(args, :timestamp)),
      correlation_id: Map.get(args, "correlation_id") || Map.get(args, :correlation_id),
      causation_id: Map.get(args, "causation_id") || Map.get(args, :causation_id),
      metadata: Map.get(args, "metadata") || Map.get(args, :metadata) || %{}
    }
  end

  defp generate_id do
    # Generate UUID v4 format string
    <<u0::48, _::4, u1::12, _::2, u2::62>> = :crypto.strong_rand_bytes(16)
    <<u0::48, 4::4, u1::12, 2::2, u2::62>> = <<u0::48, 4::4, u1::12, 2::2, u2::62>>

    <<a1::32, a2::16, a3::16, a4::16, a5::48>> = <<u0::48, 4::4, u1::12, 2::2, u2::62>>

    [
      Integer.to_string(a1, 16) |> String.downcase() |> String.pad_leading(8, "0"),
      Integer.to_string(a2, 16) |> String.downcase() |> String.pad_leading(4, "0"),
      Integer.to_string(a3, 16) |> String.downcase() |> String.pad_leading(4, "0"),
      Integer.to_string(a4, 16) |> String.downcase() |> String.pad_leading(4, "0"),
      Integer.to_string(a5, 16) |> String.downcase() |> String.pad_leading(12, "0")
    ]
    |> Enum.join("-")
  end

  defp format_timestamp(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp format_timestamp(nil), do: nil
  defp format_timestamp(str) when is_binary(str), do: str

  defp parse_timestamp(nil), do: nil
  defp parse_timestamp(%DateTime{} = dt), do: dt

  defp parse_timestamp(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _offset} -> dt
      _ -> str
    end
  end

  defp parse_timestamp(other), do: other
end
