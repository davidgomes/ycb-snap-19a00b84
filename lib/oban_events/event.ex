defmodule ObanEvents.Event do
  @moduledoc """
  Struct representing a single event occurrence, pairing event data with
  metadata about the event itself.

  `ObanEvents.emit/2` and `emit/3` build one of these structs internally and
  use it to populate the args of each dispatched `ObanEvents.DispatchWorker`
  job. You generally won't build an `ObanEvents.Event` directly in
  application code, but the struct is convenient for building fixtures in
  tests (see `ObanEvents.Testing`).

  ## Fields

  - `:name` - the event name (atom), e.g. `:user_created`
  - `:data` - the event-specific payload (map)
  - `:metadata` - additional context about the event occurrence:
    - `:id` - a unique identifier for this event occurrence (UUID string),
      useful for tracing an event across logs and the Oban Web UI
    - `:emitted_at` - the UTC `DateTime` the event was created
    - any additional keys supplied when emitting the event (e.g. `:source`)

  Metadata travels with the job through Oban, so it survives the same
  persistence round trip as `:data` (top-level keys become strings once a
  job is enqueued, e.g. `job.args["metadata"]["id"]`).
  """

  @enforce_keys [:name, :data]
  defstruct [:name, :data, metadata: %{}]

  @type t :: %__MODULE__{
          name: atom(),
          data: map(),
          metadata: map()
        }

  @doc """
  Build a new event, generating default metadata (`:id` and `:emitted_at`)
  and merging in any additional metadata supplied.

  ## Examples

      iex> event = ObanEvents.Event.new(:user_created, %{user_id: 1})
      iex> event.name
      :user_created
      iex> is_binary(event.metadata.id)
      true

      iex> event = ObanEvents.Event.new(:user_created, %{}, %{source: "signup_form"})
      iex> event.metadata.source
      "signup_form"
  """
  @spec new(atom(), map(), map()) :: t()
  def new(name, data, metadata \\ %{})
      when is_atom(name) and is_map(data) and is_map(metadata) do
    %__MODULE__{
      name: name,
      data: data,
      # Generated defaults always win so every event keeps a unique,
      # trustworthy id and timestamp, even if custom metadata happens to
      # reuse those keys.
      metadata: Map.merge(metadata, default_metadata())
    }
  end

  defp default_metadata do
    %{id: Ecto.UUID.generate(), emitted_at: DateTime.utc_now()}
  end
end
