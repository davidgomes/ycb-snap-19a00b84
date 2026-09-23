defmodule ObanEvents.Event do
  @moduledoc """
  An emitted event, as received by handlers.

  A single `%ObanEvents.Event{}` is built for each `emit/3` call and delivered to every
  handler registered for that event, so all handlers see the same `id` and `emitted_at`.

  ## Fields

  - `:id` - Unique identifier (UUID) of this emission. Shared by all handler jobs of the
    same `emit/3` call, which makes it a good idempotency key.
  - `:name` - Event name atom (e.g., `:user_created`)
  - `:data` - Event-specific data. Handlers receive it with string keys.
  - `:metadata` - Additional context that isn't part of the event payload (e.g., actor,
    request id, source). Handlers receive it with string keys. Defaults to `%{}`.
  - `:emitted_at` - UTC `DateTime` of when the event was emitted
  - `:causation_id` - `id` of the event that directly caused this one, if any
  - `:correlation_id` - Identifier shared by every event in a chain of related events.
    Defaults to the event's own `id` when not given.

  Jobs enqueued before these fields existed are still processed; missing fields are `nil`
  (or `%{}` for `:metadata`).

  ## Tracing Event Chains

  When a handler emits a follow-up event, pass the current event as `:caused_by` to link
  them. This sets `causation_id` to the current event's `id` and carries its
  `correlation_id` over:

      def handle_event(:order_placed, %Event{data: %{"order_id" => id}} = event) do
        MyApp.Events.emit(:invoice_requested, %{order_id: id}, caused_by: event)
      end
  """

  @enforce_keys [:id, :name, :data]
  defstruct [:id, :name, :data, :emitted_at, :causation_id, :correlation_id, metadata: %{}]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: atom(),
          data: map(),
          metadata: map(),
          emitted_at: DateTime.t() | nil,
          causation_id: String.t() | nil,
          correlation_id: String.t() | nil
        }

  @new_opts [:metadata, :causation_id, :correlation_id, :caused_by, :id, :emitted_at]

  @doc """
  Build a new event.

  ## Options

  - `:metadata` - Map of additional context (default: `%{}`)
  - `:causation_id` - `id` of the event that caused this one
  - `:correlation_id` - Correlation identifier (default: the event's own `id`)
  - `:caused_by` - An `%ObanEvents.Event{}` that caused this one. Sets `:causation_id` to
    its `id` and `:correlation_id` to its `correlation_id`, unless those are given explicitly.
  - `:id` - Event id (default: a generated UUID)
  - `:emitted_at` - Emission time (default: `DateTime.utc_now/0`)

  Raises `ArgumentError` on unknown options or invalid values.
  """
  @spec new(atom(), map(), keyword()) :: t()
  def new(name, data, opts \\ []) when is_atom(name) and is_map(data) and is_list(opts) do
    opts = Keyword.validate!(opts, @new_opts)

    parent =
      case Keyword.get(opts, :caused_by) do
        nil ->
          nil

        %__MODULE__{} = parent ->
          parent

        other ->
          raise ArgumentError,
                ":caused_by must be an #{inspect(__MODULE__)}, got: #{inspect(other)}"
      end

    metadata = Keyword.get(opts, :metadata, %{})

    unless is_map(metadata) do
      raise ArgumentError, ":metadata must be a map, got: #{inspect(metadata)}"
    end

    id = Keyword.get_lazy(opts, :id, &Ecto.UUID.generate/0)

    causation_id = Keyword.get_lazy(opts, :causation_id, fn -> parent && parent.id end)

    correlation_id =
      Keyword.get_lazy(opts, :correlation_id, fn ->
        (parent && (parent.correlation_id || parent.id)) || id
      end)

    %__MODULE__{
      id: id,
      name: name,
      data: data,
      metadata: metadata,
      emitted_at: Keyword.get_lazy(opts, :emitted_at, &DateTime.utc_now/0),
      causation_id: causation_id,
      correlation_id: correlation_id
    }
  end

  @doc """
  Convert an event into the string-keyed map stored in the Oban job args.
  """
  @spec to_args(t()) :: map()
  def to_args(%__MODULE__{} = event) do
    %{
      "event" => Atom.to_string(event.name),
      "event_id" => event.id,
      "data" => event.data,
      "metadata" => event.metadata,
      "emitted_at" => event.emitted_at && DateTime.to_iso8601(event.emitted_at),
      "causation_id" => event.causation_id,
      "correlation_id" => event.correlation_id
    }
  end

  @doc """
  Rebuild an event from Oban job args.

  The event name must be an existing atom.
  """
  @spec from_args(map()) :: t()
  def from_args(%{"event" => name, "data" => data} = args) do
    %__MODULE__{
      id: args["event_id"],
      name: String.to_existing_atom(name),
      data: data,
      metadata: args["metadata"] || %{},
      emitted_at: parse_datetime(args["emitted_at"]),
      causation_id: args["causation_id"],
      correlation_id: args["correlation_id"]
    }
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      {:error, _reason} -> nil
    end
  end
end
