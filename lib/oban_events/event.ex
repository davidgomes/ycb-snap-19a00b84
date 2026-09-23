defmodule ObanEvents.Event do
  @moduledoc """
  An emitted event, as delivered to handlers.

  Every call to `emit/3` produces a single event with a unique `event_id`. Each
  handler registered for that event receives the same `%ObanEvents.Event{}`,
  so the `event_id` can be used as an idempotency key.

  ## Fields

  - `:event_id` - Unique identifier (UUID) of this emission
  - `:event_name` - Atom name of the event (e.g., `:user_created`)
  - `:data` - Event-specific payload (string keys once delivered to handlers)
  - `:emitted_at` - UTC `DateTime` when the event was emitted
  - `:causation_id` - `event_id` of the event that directly caused this one, if any
  - `:correlation_id` - Identifier shared by all events in the same chain/workflow.
    Defaults to the `event_id` when not given, so the first event starts a new chain
  - `:metadata` - Arbitrary JSON-serializable map (e.g., actor, request id, source)

  ## Chaining Events

  Use `caused_by/1` to emit follow-up events from a handler while preserving
  causation and correlation:

      def handle_event(:order_placed, %Event{} = event) do
        MyApp.Events.emit(:invoice_requested, %{order_id: event.data["order_id"]},
          ObanEvents.Event.caused_by(event)
        )
      end
  """

  @enforce_keys [:event_id, :event_name, :data]
  defstruct [
    :event_id,
    :event_name,
    :data,
    :emitted_at,
    :causation_id,
    :correlation_id,
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          event_id: String.t() | nil,
          event_name: atom(),
          data: map(),
          emitted_at: DateTime.t() | nil,
          causation_id: String.t() | nil,
          correlation_id: String.t() | nil,
          metadata: map()
        }

  @doc """
  Build a new event.

  ## Options

  - `:causation_id` - `event_id` of the causing event
  - `:correlation_id` - Correlation identifier (defaults to the generated `event_id`)
  - `:metadata` - Map of additional metadata (default: `%{}`)
  """
  @spec new(atom(), map(), keyword()) :: t()
  def new(event_name, data, opts \\ []) when is_atom(event_name) and is_map(data) do
    event_id = Ecto.UUID.generate()

    %__MODULE__{
      event_id: event_id,
      event_name: event_name,
      data: data,
      emitted_at: DateTime.utc_now(),
      causation_id: Keyword.get(opts, :causation_id),
      correlation_id: Keyword.get(opts, :correlation_id) || event_id,
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Returns `emit/3` options for an event caused by `event`.

  The new event's `causation_id` is set to `event.event_id` and its
  `correlation_id` is inherited from `event`. Pass `:metadata` to attach
  metadata to the new event.
  """
  @spec caused_by(t(), keyword()) :: keyword()
  def caused_by(%__MODULE__{} = event, opts \\ []) do
    Keyword.merge(
      [causation_id: event.event_id, correlation_id: event.correlation_id || event.event_id],
      opts
    )
  end

  @doc false
  @spec to_job_args(t(), module()) :: map()
  def to_job_args(%__MODULE__{} = event, handler) do
    %{
      event: Atom.to_string(event.event_name),
      handler: Atom.to_string(handler),
      data: event.data,
      event_id: event.event_id,
      emitted_at: event.emitted_at && DateTime.to_iso8601(event.emitted_at),
      causation_id: event.causation_id,
      correlation_id: event.correlation_id,
      metadata: event.metadata
    }
  end

  @doc false
  @spec from_job_args(atom(), map()) :: t()
  def from_job_args(event_name, %{"data" => data} = args) do
    %__MODULE__{
      event_id: args["event_id"],
      event_name: event_name,
      data: data,
      emitted_at: parse_datetime(args["emitted_at"]),
      causation_id: args["causation_id"],
      correlation_id: args["correlation_id"],
      metadata: args["metadata"] || %{}
    }
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      {:error, _} -> nil
    end
  end
end
