defmodule Nostrum.Struct.Message.Attachment do
  @moduledoc """
  Struct representing a Discord message attachment.
  """

  alias Nostrum.{Snowflake, Util}

  defstruct [
    :id,
    :filename,
    :title,
    :description,
    :content_type,
    :size,
    :url,
    :proxy_url,
    :height,
    :width,
    :ephemeral,
    :duration_secs,
    :waveform,
    :flags
  ]

  @typedoc "Attachment id"
  @type id :: Snowflake.t()

  @typedoc "Name of attached file"
  @type filename :: String.t()

  @typedoc "The title of the file"
  @typedoc since: "NEXTVERSION"
  @type title :: String.t() | nil

  @typedoc "Description for the file (max 1024 characters)"
  @typedoc since: "NEXTVERSION"
  @type description :: String.t() | nil

  @typedoc "The attachment’s media type"
  @typedoc since: "NEXTVERSION"
  @type content_type :: String.t() | nil

  @typedoc "Size of the file in bytes"
  @type size :: integer

  @typedoc "Source url of the file"
  @type url :: String.t()

  @typedoc "Proxy url of the file"
  @type proxy_url :: String.t()

  @typedoc "Height of the file (if image)"
  @type height :: integer | nil

  @typedoc "Width of the file (if image)"
  @type width :: integer | nil

  @typedoc "Whether this attachment is ephemeral"
  @typedoc since: "NEXTVERSION"
  @type ephemeral :: boolean | nil

  @typedoc "The duration of the audio file in seconds (currently for voice messages)"
  @typedoc since: "NEXTVERSION"
  @type duration_secs :: float | nil

  @typedoc "Base64 encoded bytearray representing a sampled waveform (currently for voice messages)"
  @typedoc since: "NEXTVERSION"
  @type waveform :: String.t() | nil

  @typedoc "Attachment flags combined as a bitfield"
  @typedoc since: "NEXTVERSION"
  @type flags :: integer | nil

  @type t :: %__MODULE__{
          id: id,
          filename: filename,
          title: title,
          description: description,
          content_type: content_type,
          size: size,
          url: url,
          proxy_url: proxy_url,
          height: height,
          width: width,
          ephemeral: ephemeral,
          duration_secs: duration_secs,
          waveform: waveform,
          flags: flags
        }

  @doc false
  def to_struct(map) do
    new =
      map
      |> Map.new(fn {k, v} -> {Util.maybe_to_atom(k), v} end)
      |> Map.update(:id, nil, &Util.cast(&1, Snowflake))

    struct(__MODULE__, new)
  end
end
