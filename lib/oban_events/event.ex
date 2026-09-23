defmodule ObanEvents.Event do
  @moduledoc """
  An event as delivered to a handler.

  ## Fields

  - `:id` - Unique event identifier (UUID), shared by all handler jobs of one emit
  - `:name` - Event name atom (e.g., `:user_created`)
  - `:data` - Event payload with string keys
  - `:metadata` - Arbitrary user metadata with string keys (e.g., `%{"actor_id" => 1}`)
  - `:causation_id` - ID of the event that caused this one, if any
  - `:correlation_id` - ID tying together a chain of related events
  - `:emitted_at` - `DateTime` when the event was emitted
  """

  @enforce_keys [:id, :name]
  defstruct [:id, :name, :causation_id, :correlation_id, :emitted_at, data: %{}, metadata: %{}]

  @type t :: %__MODULE__{
          id: String.t(),
          name: atom(),
          data: map(),
          metadata: map(),
          causation_id: String.t() | nil,
          correlation_id: String.t() | nil,
          emitted_at: DateTime.t() | nil
        }

  @doc """
  Builds a new event, generating an id and `emitted_at` timestamp.

  ## Options

  - `:metadata` - map of additional metadata (default: `%{}`)
  - `:causation_id` - id of the causing event
  - `:correlation_id` - correlation id (defaults to the causing event's correlation id
    when `:caused_by` is given, otherwise the new event's own id)
  - `:caused_by` - an `ObanEvents.Event` that caused this one; sets `:causation_id`
    and `:correlation_id` from it
  """
  @spec new(atom(), map(), keyword()) :: t()
  def new(name, data \\ %{}, opts \\ []) when is_atom(name) and is_map(data) do
    id = Keyword.get_lazy(opts, :id, &Ecto.UUID.generate/0)
    parent = Keyword.get(opts, :caused_by)

    %__MODULE__{
      id: id,
      name: name,
      data: data,
      metadata: Keyword.get(opts, :metadata, %{}),
      causation_id: Keyword.get(opts, :causation_id, parent && parent.id),
      correlation_id:
        Keyword.get(opts, :correlation_id, (parent && (parent.correlation_id || parent.id)) || id),
      emitted_at: Keyword.get_lazy(opts, :emitted_at, fn -> DateTime.utc_now() end)
    }
  end

  @doc false
  @spec to_args(t(), module()) :: map()
  def to_args(%__MODULE__{} = event, handler) do
    %{
      "event" => Atom.to_string(event.name),
      "handler" => Atom.to_string(handler),
      "data" => event.data,
      "event_id" => event.id,
      "metadata" => event.metadata,
      "causation_id" => event.causation_id,
      "correlation_id" => event.correlation_id,
      "emitted_at" => event.emitted_at && DateTime.to_iso8601(event.emitted_at)
    }
  end

  @doc false
  @spec from_args(map(), Oban.Job.t() | nil) :: t()
  def from_args(%{"event" => name, "data" => data} = args, job \\ nil) do
    %__MODULE__{
      id: args["event_id"] || (job && job.id && to_string(job.id)),
      name: String.to_existing_atom(name),
      data: data,
      metadata: args["metadata"] || %{},
      causation_id: args["causation_id"],
      correlation_id: args["correlation_id"],
      emitted_at: parse_datetime(args["emitted_at"]) || (job && job.inserted_at)
    }
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(string) when is_binary(string) do
    case DateTime.from_iso8601(string) do
      {:ok, dt, _offset} -> dt
      _ -> nil
    end
  end
end
