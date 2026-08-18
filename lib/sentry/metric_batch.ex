defmodule Sentry.MetricBatch do
  @moduledoc """
  A batch of metric events to be sent in a single envelope item.

  According to the Sentry Metrics Protocol, metrics are sent in batches
  within a single envelope item with content type `application/vnd.sentry.items.trace-metric+json`.
  """
  @moduledoc since: "13.0.0"

  alias Sentry.{Config, Metric}

  @type t() :: %__MODULE__{
          metrics: [Metric.t()]
        }

  @enforce_keys [:metrics]
  defstruct [:metrics]

  @doc """
  Calculates the byte size of a metric batch payload when encoded to JSON.
  """
  @doc since: "13.4.0"
  @spec byte_size(t()) :: non_neg_integer()
  def byte_size(%__MODULE__{metrics: metrics}) do
    items = Enum.map(metrics, &Metric.to_map/1)
    payload = %{items: items}

    case Sentry.JSON.encode(payload, Config.json_library()) do
      {:ok, encoded} -> Kernel.byte_size(encoded)
      {:error, _reason} -> 0
    end
  end
end
