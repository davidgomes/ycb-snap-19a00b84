defmodule Sentry.ClientReport.Sender do
  @moduledoc false

  # This module is responsible for storing client reports and periodically "flushing"
  # them to Sentry.

  use GenServer

  alias Sentry.{
    Attachment,
    CheckIn,
    Client,
    ClientReport,
    Config,
    Envelope,
    Event,
    LogBatch,
    LogEvent,
    Metric,
    MetricBatch,
    Transaction
  }

  @send_interval 30_000

  @client_report_reasons ClientReport.reasons()

  @spec start_link([]) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc """
  Synchronously sends any pending client reports and clears the accumulated state.
  """
  @spec flush(GenServer.server()) :: :ok
  def flush(server \\ __MODULE__) do
    GenServer.call(server, :flush)
  end

  def record_discarded_events(reason, info, genserver \\ __MODULE__)

  @spec record_discarded_events(atom(), String.t(), GenServer.server()) :: :ok
  def record_discarded_events(reason, data_category, genserver)
      when is_binary(data_category) do
    GenServer.cast(genserver, {:record_discarded_events, reason, data_category, 1})
  end

  @spec record_discarded_events(atom(), [item], GenServer.server()) :: :ok
        when item:
               Attachment.t()
               | CheckIn.t()
               | ClientReport.t()
               | Event.t()
               | LogBatch.t()
               | LogEvent.t()
               | Metric.t()
               | MetricBatch.t()
               | Transaction.t()
  def record_discarded_events(reason, event_items, genserver)
      when is_list(event_items) do
    # We silently ignore events whose reasons aren't valid because we have to add it to the allowlist in Snuba
    # https://develop.sentry.dev/sdk/client-reports/
    if Enum.member?(@client_report_reasons, reason) do
      Enum.each(event_items, fn item ->
        for {category, quantity} <- data_categories(item) do
          GenServer.cast(genserver, {:record_discarded_events, reason, category, quantity})
        end
      end)
    end

    :ok
  end

  # A dropped transaction also drops the spans it contains. Per Sentry's client
  # report spec, we must record an additional `span` outcome whose quantity is
  # the number of spans in the transaction plus one, because Relay extracts an
  # extra span from the transaction itself.
  # https://develop.sentry.dev/sdk/telemetry/client-reports/#span-outcomes
  defp data_categories(%Transaction{spans: spans} = transaction) do
    span_count = length(List.wrap(spans)) + 1
    [{Envelope.get_data_category(transaction), 1}, {"span", span_count}]
  end

  defp data_categories(%LogEvent{} = log_event) do
    [
      {Envelope.get_data_category(log_event), 1},
      {"log_byte", LogEvent.byte_size(log_event)}
    ]
  end

  defp data_categories(%LogBatch{log_events: log_events} = log_batch) do
    [
      {Envelope.get_data_category(log_batch), length(log_events)},
      {"log_byte", LogBatch.byte_size(log_batch)}
    ]
  end

  defp data_categories(%Metric{} = metric) do
    [
      {Envelope.get_data_category(metric), 1},
      {"trace_metric_byte", Metric.byte_size(metric)}
    ]
  end

  defp data_categories(%MetricBatch{metrics: metrics} = metric_batch) do
    [
      {Envelope.get_data_category(metric_batch), length(metrics)},
      {"trace_metric_byte", MetricBatch.byte_size(metric_batch)}
    ]
  end

  defp data_categories(item) when is_struct(item) do
    [{Envelope.get_data_category(item), 1}]
  end

  defp data_categories(_item) do
    []
  end

  ## Callbacks

  @impl true
  def init(opts) do
    schedule_report()

    if rate_limiter_table_name = Keyword.get(opts, :rate_limiter_table_name) do
      Process.put(:rate_limiter_table_name, rate_limiter_table_name)
    end

    {:ok, _state = %{}}
  end

  @impl true
  def handle_cast({:record_discarded_events, reason, category, quantity}, discarded_events) do
    {:noreply, Map.update(discarded_events, {reason, category}, quantity, &(&1 + quantity))}
  end

  @impl true
  def handle_call(:flush, _from, state) do
    send_pending_reports(state)
    {:reply, :ok, %{}}
  end

  @impl true
  def handle_info(:send_report, state) do
    send_pending_reports(state)
    schedule_report()
    {:noreply, %{}}
  end

  defp send_pending_reports(state) do
    _result =
      if map_size(state) != 0 and Config.dsn() != nil and Config.send_client_reports?() do
        client_report = %ClientReport{
          timestamp:
            DateTime.utc_now()
            |> DateTime.truncate(:second)
            |> DateTime.to_iso8601()
            |> String.trim_trailing("Z"),
          discarded_events:
            Enum.map(state, fn {{reason, category}, quantity} ->
              %{
                reason: reason,
                category: category,
                quantity: quantity
              }
            end)
        }

        Client.send_client_report(client_report)
      end

    :ok
  end

  defp schedule_report do
    Process.send_after(self(), :send_report, @send_interval)
  end
end
