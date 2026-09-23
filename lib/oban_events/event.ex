defmodule ObanEvents.Event do
  @moduledoc """
  An emitted event, as delivered to handlers.

  Every call to `emit/3` builds one event. Each registered handler receives it
  through its own Oban job, so all handlers of a single emission share the same
  `id`, `data`, `metadata`, and `emitted_at`, while `job_id` and `attempt` are
  specific to each handler's job.

  ## Fields

  - `:id` - UUID generated at emit time, shared by every handler of the emission.
    Useful as an idempotency or correlation key.
  - `:name` - Event name (e.g. `:user_created`)
  - `:data` - Event-specific data, always with string keys
  - `:metadata` - Additional context passed via the `:metadata` option of `emit/3`
    (e.g. actor, request, or correlation IDs), always with string keys. Defaults to `%{}`.
  - `:emitted_at` - UTC `DateTime` when the event was emitted
  - `:job_id` - ID of the Oban job delivering the event to this handler
  - `:attempt` - Delivery attempt for this handler, starting at `1`

  Jobs enqueued before these fields existed are still delivered: `:id` is `nil`,
  `:metadata` is `%{}`, and `:emitted_at` falls back to the job's `inserted_at`.

  ## Example

      def handle_event(:user_created, %ObanEvents.Event{data: data, metadata: metadata} = event) do
        %{"user_id" => user_id} = data
        Logger.info("user \#{user_id} created by \#{metadata["actor_id"]} (event \#{event.id})")
        :ok
      end
  """

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          name: atom(),
          data: map(),
          metadata: map(),
          emitted_at: DateTime.t() | nil,
          job_id: integer() | nil,
          attempt: non_neg_integer() | nil
        }

  @enforce_keys [:name]
  defstruct [:id, :name, :emitted_at, :job_id, :attempt, data: %{}, metadata: %{}]

  @doc false
  @spec new(atom(), map(), keyword()) :: t()
  def new(name, data, opts \\ []) when is_atom(name) and is_map(data) and is_list(opts) do
    metadata = Keyword.get(opts, :metadata, %{})

    unless is_map(metadata) do
      raise ArgumentError, "expected :metadata to be a map, got: #{inspect(metadata)}"
    end

    %__MODULE__{
      id: Ecto.UUID.generate(),
      name: name,
      data: data,
      metadata: metadata,
      emitted_at: DateTime.utc_now()
    }
  end

  @doc false
  @spec to_job_args(t(), module()) :: map()
  def to_job_args(%__MODULE__{} = event, handler) when is_atom(handler) do
    %{
      "event" => Atom.to_string(event.name),
      "handler" => Atom.to_string(handler),
      "data" => event.data,
      "event_id" => event.id,
      "emitted_at" => event.emitted_at && DateTime.to_iso8601(event.emitted_at),
      "metadata" => event.metadata
    }
  end

  @doc false
  @spec from_job(Oban.Job.t()) :: t()
  def from_job(%Oban.Job{args: %{"event" => name, "data" => data} = args} = job) do
    %__MODULE__{
      id: args["event_id"],
      name: String.to_existing_atom(name),
      data: data,
      metadata: args["metadata"] || %{},
      emitted_at: parse_datetime(args["emitted_at"]) || job.inserted_at,
      job_id: job.id,
      attempt: job.attempt
    }
  end

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      {:error, _reason} -> nil
    end
  end

  defp parse_datetime(_value), do: nil
end
