defmodule Sentry.LogBatch do
  @moduledoc """
  A batch of log events to be sent in a single envelope item.

  According to the Sentry Logs Protocol, log events are sent in batches
  within a single envelope item with content type `application/vnd.sentry.items.log+json`.
  """
  @moduledoc since: "12.0.0"

  alias Sentry.{Config, LogEvent}

  @type t() :: %__MODULE__{
          log_events: [LogEvent.t()]
        }

  @enforce_keys [:log_events]
  defstruct [:log_events]

  @doc """
  Calculates the byte size of a log batch payload when encoded to JSON.
  """
  @doc since: "13.4.0"
  @spec byte_size(t()) :: non_neg_integer()
  def byte_size(%__MODULE__{log_events: log_events}) do
    items = Enum.map(log_events, &LogEvent.to_map/1)
    payload = %{items: items}

    case Sentry.JSON.encode(payload, Config.json_library()) do
      {:ok, encoded} -> Kernel.byte_size(encoded)
      {:error, _reason} -> 0
    end
  end
end
