defmodule ObanEvents.Event do
  @moduledoc """
  Struct representing a single emission of an event to a specific handler.

  Alongside the event `name` and `data` payload, an `ObanEvents.Event` carries
  observability metadata that is useful for tracing an event through the
  system:

  - `:id` - a unique identifier for this emission, shared by every handler's
    job for a given `emit/3` call so related jobs can be correlated (e.g. in
    logs, traces, or the Oban Web UI)
  - `:handler` - the handler module the resulting job will dispatch to
  - `:emitted_at` - the UTC timestamp the event was emitted
  - `:metadata` - an arbitrary, caller-supplied map of additional context
    (e.g. `:actor_id`, `:correlation_id`, `:source`) that travels alongside
    the event without being mixed into its `data` payload

  This struct is built internally by `emit/3` for every registered handler,
  then serialized into `ObanEvents.DispatchWorker` job args via `to_args/1`.
  It isn't meant to be constructed directly by consumers of `ObanEvents`.
  """

  @enforce_keys [:id, :name, :handler, :data, :metadata, :emitted_at]
  defstruct [:id, :name, :handler, :data, :metadata, :emitted_at]

  @type t :: %__MODULE__{
          id: String.t(),
          name: atom(),
          handler: module(),
          data: map(),
          metadata: map(),
          emitted_at: DateTime.t()
        }

  @doc """
  Build a new event for a specific handler.

  Stamps the event with a unique `:id` and the current UTC `:emitted_at`
  timestamp. `metadata` defaults to an empty map when omitted.

  ## Examples

      iex> event = ObanEvents.Event.new(:user_created, %{user_id: 1}, MyApp.EmailHandler)
      iex> event.name
      :user_created
  """
  @spec new(atom(), map(), module(), map()) :: t()
  def new(name, data, handler, metadata \\ %{})
      when is_atom(name) and is_map(data) and is_atom(handler) and is_map(metadata) do
    %__MODULE__{
      id: unique_id(),
      name: name,
      handler: handler,
      data: data,
      metadata: metadata,
      emitted_at: DateTime.utc_now()
    }
  end

  @doc """
  Convert an event into the plain, string-keyed map used as
  `ObanEvents.DispatchWorker` job args.
  """
  @spec to_args(t()) :: map()
  def to_args(%__MODULE__{} = event) do
    %{
      "event" => Atom.to_string(event.name),
      "handler" => Atom.to_string(event.handler),
      "data" => event.data,
      "metadata" => event.metadata,
      "event_id" => event.id,
      "emitted_at" => DateTime.to_iso8601(event.emitted_at)
    }
  end

  defp unique_id do
    16
    |> :crypto.strong_rand_bytes()
    |> Base.encode16(case: :lower)
  end
end
