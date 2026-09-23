defmodule SpiderMan.Stats do
  @moduledoc false
  @components [:downloader, :spider, :item_processor]
  @events [
    [:spider_man, :downloader, :start],
    [:spider_man, :downloader, :stop],
    [:spider_man, :spider, :start],
    [:spider_man, :spider, :stop],
    [:spider_man, :item_processor, :start],
    [:spider_man, :item_processor, :stop]
  ]

  def attach_spider_stats(spider, tid) do
    name = inspect(spider)

    for event <- @events do
      id = {__MODULE__, event, self()}
      :telemetry.attach(id, event, &__MODULE__.update_spider_stats/4, {name, tid})
    end
  end

  def detach_spider_stats do
    for event <- @events do
      :telemetry.detach({__MODULE__, event, self()})
    end
  end

  if Mix.env() != :test do
    def print_spider_stats(tid, true),
      do: IO.write("\e[2K\r#{tid |> get_stats() |> format_stats()} ")
  else
    def print_spider_stats(tid, true), do: tid |> get_stats() |> format_stats()
  end

  def print_spider_stats(tid, fun) when is_function(fun, 1), do: tid |> get_stats() |> fun.()

  def get_stats(tid) do
    Enum.map(@components, fn component ->
      [{^component, total, success, fail, duration}] = :ets.lookup(tid, component)
      ms = System.convert_time_unit(duration, :native, :millisecond)
      tps = if ms == 0, do: 0, else: Float.floor(success / (ms / 1000), 2)

      %{
        component: component,
        total: total,
        success: success,
        fail: fail,
        duration: ms,
        tps: tps
      }
    end)
  end

  def format_stats(stats), do: Enum.map_join(stats, " ", &format_component_stats/1)

  defp format_component_stats(%{
         component: component,
         total: total,
         success: success,
         fail: fail,
         tps: tps
       }) do
    tps = if tps > 999, do: "999+", else: tps
    component = Atom.to_string(component) |> Macro.camelize()
    "#{component}:[#{success}/#{total} #{tps}/s F:#{fail}]"
  end

  def update_spider_stats([_, component, :start], measurements, metadata, {name, tid}) do
    if match?(%{name: ^name}, metadata) do
      :ets.update_counter(tid, component, {2, measurements.count})
    end
  end

  def update_spider_stats([_, component, :stop], measurements, metadata, {name, tid}) do
    if match?(%{name: ^name}, metadata) do
      %{success: success, fail: fail, duration: duration} = measurements
      :ets.update_counter(tid, component, [{3, success}, {4, fail}, {5, duration}])
    end
  end
end

defmodule SpiderMan.Stats.Task do
  @moduledoc false
  use GenServer

  def start_link(state), do: GenServer.start_link(__MODULE__, state)
  def suspend(nil), do: :skiped
  def suspend(pid), do: GenServer.call(pid, :suspend)
  def continue(nil), do: :skiped
  def continue(pid), do: GenServer.call(pid, :continue)

  def init(state) do
    {:ok, state, 1000}
  end

  def handle_call(:suspend, _from, state) do
    {:reply, :ok, %{state | status: :suspended}}
  end

  def handle_call(:continue, _from, %{status: :suspended} = state) do
    Process.send_after(self(), :refresh, state.refresh_interval)
    {:reply, :ok, %{state | status: :running}}
  end

  def handle_call(:continue, _from, state) do
    {:reply, :ok, state}
  end

  def handle_info(:refresh, %{status: :running, refresh_interval: interval, tid: tid} = state) do
    Process.send_after(self(), :refresh, interval)
    SpiderMan.Stats.print_spider_stats(tid, state.print_stats)
    {:noreply, state}
  end

  def handle_info(:refresh, state) do
    {:noreply, state}
  end

  def handle_info(:timeout, state) do
    Process.send_after(self(), :refresh, state.refresh_interval)
    {:noreply, state}
  end
end
