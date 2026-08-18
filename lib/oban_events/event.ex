defmodule ObanEvents.Event do
  @moduledoc """
  Struct describing a single emitted event, its payload and its metadata.

  Every call to `emit/3` builds one event and turns it into one Oban job per
  registered handler. Alongside the payload, an event carries metadata that is
  useful for tracing and debugging:

  - `:id` - unique id shared by every handler job created for the same emit call
  - `:emitted_at` - when the event was emitted (not when it is processed)
  - `:meta` - arbitrary metadata supplied by the emitter (actor, request id, ...)
  - `:handler` - the handler module the event is being dispatched to
  - `:job_id`, `:attempt`, `:max_attempts` - Oban job details while processing

  Handlers that implement `handle_event/3` receive the struct as the third
  argument:

      defmodule MyApp.AuditHandler do
        use ObanEvents.Handler

        @impl true
        def handle_event(name, data, %ObanEvents.Event{} = event) do
          MyApp.Audit.record(name, data,
            event_id: event.id,
            actor_id: event.meta["actor_id"],
            emitted_at: event.emitted_at
          )
        end
      end

  ## Serialization

  Payloads and metadata are stored in the Oban job's `args`, so both must be
  JSON-serializable. Map keys are normalized to strings when the event is built,
  matching what handlers receive after the job round-trips through the database.
  """

  @enforce_keys [:name]
  defstruct [
    :id,
    :name,
    :handler,
    :emitted_at,
    :job_id,
    :attempt,
    :max_attempts,
    data: %{},
    meta: %{}
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: atom(),
          handler: module() | nil,
          emitted_at: DateTime.t() | nil,
          job_id: integer() | nil,
          attempt: pos_integer() | nil,
          max_attempts: pos_integer() | nil,
          data: map(),
          meta: map()
        }

  @doc """
  Build an event named `name` carrying `data`.

  ## Options

  - `:meta` - metadata map carried alongside the payload (default: `%{}`)
  - `:id` - unique event id (default: a generated UUID)
  - `:emitted_at` - `DateTime` the event was emitted (default: `DateTime.utc_now/0`)
  - `:handler` - handler module the event is dispatched to
  - `:job_id`, `:attempt`, `:max_attempts` - Oban job details, normally filled
    in by `from_job/1`

  Unknown options are ignored so job options can be passed through untouched.

  ## Examples

      iex> event = ObanEvents.Event.new(:user_created, %{user_id: 1}, meta: %{actor_id: 7})
      iex> event.data
      %{"user_id" => 1}
      iex> event.meta
      %{"actor_id" => 7}
  """
  @spec new(atom(), map(), keyword()) :: t()
  def new(name, data \\ %{}, opts \\ []) when is_atom(name) and is_map(data) and is_list(opts) do
    %__MODULE__{
      id: validate_id!(Keyword.get(opts, :id) || generate_id()),
      name: name,
      handler: validate_handler!(Keyword.get(opts, :handler)),
      emitted_at: validate_emitted_at!(Keyword.get(opts, :emitted_at) || DateTime.utc_now()),
      job_id: Keyword.get(opts, :job_id),
      attempt: Keyword.get(opts, :attempt),
      max_attempts: Keyword.get(opts, :max_attempts),
      data: normalize_payload(data),
      meta: normalize_payload(validate_meta!(Keyword.get(opts, :meta, %{})))
    }
  end

  @doc """
  Return a copy of the event that is dispatched to `handler`.
  """
  @spec for_handler(t(), module()) :: t()
  def for_handler(%__MODULE__{} = event, handler) when is_atom(handler) and not is_nil(handler) do
    %{event | handler: handler}
  end

  @doc """
  Build the Oban job args for an event.

  Requires a `:handler`, see `for_handler/2`.
  """
  @spec to_args(t()) :: map()
  def to_args(%__MODULE__{handler: nil}) do
    raise ArgumentError, "cannot build job args for an event without a :handler"
  end

  def to_args(%__MODULE__{} = event) do
    %{
      "event" => Atom.to_string(event.name),
      "handler" => Atom.to_string(event.handler),
      "data" => event.data,
      "meta" => event.meta,
      "event_id" => event.id,
      "emitted_at" => encode_emitted_at(event.emitted_at)
    }
  end

  @doc """
  Rebuild an event from the Oban job that carries it.

  Returns `:error` when the job args don't describe an event. Metadata that is
  missing from the args, as is the case for jobs enqueued before metadata was
  introduced, falls back to the job's own values or `nil`.
  """
  @spec from_job(Oban.Job.t()) :: {:ok, t()} | :error
  def from_job(%Oban.Job{args: %{"event" => name, "handler" => handler, "data" => data}} = job)
      when is_binary(name) and is_binary(handler) and is_map(data) do
    event = %__MODULE__{
      id: Map.get(job.args, "event_id"),
      # These atoms already exist, they were created when the event was emitted.
      name: String.to_existing_atom(name),
      handler: String.to_existing_atom(handler),
      emitted_at: decode_emitted_at(Map.get(job.args, "emitted_at")) || job.inserted_at,
      job_id: job.id,
      attempt: job.attempt,
      max_attempts: job.max_attempts,
      data: data,
      meta: Map.get(job.args, "meta") || %{}
    }

    {:ok, event}
  end

  def from_job(%Oban.Job{}), do: :error

  @doc """
  Normalize a payload the way it is stored in job args, with string keys.

  Structs and non-map values are left untouched, they are handled by the JSON
  encoder when the job is inserted.
  """
  @spec normalize_payload(term()) :: term()
  def normalize_payload(%_struct{} = value), do: value

  def normalize_payload(value) when is_map(value) do
    Map.new(value, fn {key, val} -> {normalize_key(key), normalize_payload(val)} end)
  end

  def normalize_payload(value) when is_list(value), do: Enum.map(value, &normalize_payload/1)
  def normalize_payload(value), do: value

  defp normalize_key(key) when is_binary(key), do: key
  defp normalize_key(key) when is_atom(key), do: Atom.to_string(key)
  defp normalize_key(key), do: to_string(key)

  defp generate_id, do: Ecto.UUID.generate()

  defp validate_id!(id) when is_binary(id), do: id

  defp validate_id!(id) do
    raise ArgumentError, "event :id must be a string, got: #{inspect(id)}"
  end

  defp validate_handler!(nil), do: nil
  defp validate_handler!(handler) when is_atom(handler), do: handler

  defp validate_handler!(handler) do
    raise ArgumentError, "event :handler must be a module, got: #{inspect(handler)}"
  end

  defp validate_emitted_at!(%DateTime{} = emitted_at), do: emitted_at

  defp validate_emitted_at!(emitted_at) do
    raise ArgumentError, "event :emitted_at must be a DateTime, got: #{inspect(emitted_at)}"
  end

  defp validate_meta!(meta) when is_map(meta), do: meta

  defp validate_meta!(meta) do
    raise ArgumentError, "event :meta must be a map, got: #{inspect(meta)}"
  end

  defp encode_emitted_at(nil), do: nil
  defp encode_emitted_at(%DateTime{} = emitted_at), do: DateTime.to_iso8601(emitted_at)

  defp decode_emitted_at(nil), do: nil

  defp decode_emitted_at(emitted_at) when is_binary(emitted_at) do
    case DateTime.from_iso8601(emitted_at) do
      {:ok, datetime, _offset} -> datetime
      {:error, _reason} -> nil
    end
  end
end
