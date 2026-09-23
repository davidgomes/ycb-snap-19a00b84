defmodule ObanEvents.Event do
  @moduledoc """
  An event delivered to handlers.

  ## Fields

  - `:event_id` - Unique identifier (UUID v4) generated at emit time. Shared by all
    handler jobs of a single emit, useful as an idempotency key.
  - `:name` - Event name atom (e.g. `:user_created`)
  - `:data` - Event payload with string keys
  - `:metadata` - Arbitrary map of additional metadata with string keys
  - `:causation_id` - ID of the event that caused this one (optional)
  - `:correlation_id` - ID shared by a chain of related events. Defaults to `event_id`.
  - `:emitted_at` - `DateTime` (UTC) when the event was emitted
  - `:handler` - Handler module processing the event
  - `:job_id` - Oban job ID (`nil` outside Oban)
  - `:attempt` - Current Oban attempt (`1` outside Oban)
  """

  @enforce_keys [:event_id, :name]
  defstruct [
    :event_id,
    :name,
    :causation_id,
    :correlation_id,
    :emitted_at,
    :handler,
    :job_id,
    data: %{},
    metadata: %{},
    attempt: 1
  ]

  @type t :: %__MODULE__{
          event_id: String.t(),
          name: atom(),
          data: map(),
          metadata: map(),
          causation_id: String.t() | nil,
          correlation_id: String.t() | nil,
          emitted_at: DateTime.t() | nil,
          handler: module() | nil,
          job_id: integer() | nil,
          attempt: pos_integer()
        }

  @doc """
  Builds a new event, generating `event_id` and `emitted_at`.

  ## Options

  - `:metadata` - Map of additional metadata (default: `%{}`)
  - `:causation_id` - ID of the causing event
  - `:correlation_id` - Correlation ID (default: the generated `event_id`)
  - `:event_id` - Override the generated event ID
  - `:emitted_at` - Override the emission time
  """
  @spec new(atom(), map(), keyword()) :: t()
  def new(name, data \\ %{}, opts \\ []) when is_atom(name) and is_map(data) do
    event_id = Keyword.get_lazy(opts, :event_id, &generate_id/0)

    %__MODULE__{
      event_id: event_id,
      name: name,
      data: stringify_keys(data),
      metadata: stringify_keys(Keyword.get(opts, :metadata, %{})),
      causation_id: Keyword.get(opts, :causation_id),
      correlation_id: Keyword.get(opts, :correlation_id, event_id),
      emitted_at: Keyword.get_lazy(opts, :emitted_at, &utc_now/0),
      handler: Keyword.get(opts, :handler)
    }
  end

  @doc """
  Returns options for emitting a follow-up event caused by `event`.

      MyApp.Events.emit(:welcome_sent, data, ObanEvents.Event.caused_by(event))
  """
  @spec caused_by(t()) :: keyword()
  def caused_by(%__MODULE__{event_id: event_id, correlation_id: correlation_id}) do
    [causation_id: event_id, correlation_id: correlation_id || event_id]
  end

  @doc false
  @spec to_args(t(), module()) :: map()
  def to_args(%__MODULE__{} = event, handler) do
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
  @spec from_job(Oban.Job.t(), atom(), module()) :: t()
  def from_job(%Oban.Job{args: args} = job, name, handler) do
    %__MODULE__{
      event_id: Map.get(args, "event_id") || generate_id(),
      name: name,
      data: Map.get(args, "data", %{}),
      metadata: Map.get(args, "metadata") || %{},
      causation_id: Map.get(args, "causation_id"),
      correlation_id: Map.get(args, "correlation_id"),
      emitted_at: parse_datetime(Map.get(args, "emitted_at")) || job.inserted_at,
      handler: handler,
      job_id: job.id,
      attempt: job.attempt || 1
    }
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      _ -> nil
    end
  end

  defp utc_now, do: DateTime.utc_now() |> DateTime.truncate(:microsecond)

  defp generate_id do
    <<a::48, _::4, b::12, _::2, c::62>> = :crypto.strong_rand_bytes(16)
    <<u0::32, u1::16, u2::16, u3::16, u4::48>> = <<a::48, 4::4, b::12, 2::2, c::62>>

    [u0, u1, u2, u3, u4]
    |> Enum.zip([8, 4, 4, 4, 12])
    |> Enum.map_join("-", fn {int, len} ->
      int |> Integer.to_string(16) |> String.pad_leading(len, "0") |> String.downcase()
    end)
  end

  defp stringify_keys(map) when is_map(map) do
    map |> Jason.encode!() |> Jason.decode!()
  end
end
