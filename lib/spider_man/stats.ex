defmodule SpiderMan.Stats do
  @moduledoc """
  Throughput statistics for spiders.

  Each spider counts the events handled by theirs components, then you can fetch
  those infos by `get_stats/1`, e.g.:

      SpiderMan.Stats.get_stats(MySpider)
      #=> [
      #     %{component: :downloader, total: 30, success: 20, fail: 0, duration_ms: 2_000, tps: 10.0},
      #     %{component: :spider, ...},
      #     %{component: :item_processor, ...}
      #   ]

  By default those infos are printed to the console every second, that's useless
  on livebook, so you can turn it off by `print_stats: false` setting, and render
  the infos with [kino](https://hexdocs.pm/kino) instead:

      Kino.animate(1000, fn _ ->
        SpiderMan.Stats.get_stats(MySpider) |> Kino.DataTable.new()
      end)

  Or let the spider push those infos for you by `print_stats: [callback: fun]` setting:

      frame = Kino.Frame.new() |> Kino.render()

      settings = [
        print_stats: [
          interval: 1000,
          callback: fn stats -> Kino.Frame.render(frame, Kino.DataTable.new(stats)) end
        ]
      ]
  """
  @components [:downloader, :spider, :item_processor]
  @events Enum.flat_map(@components, &[[:spider_man, &1, :start], [:spider_man, &1, :stop]])

  @type component_stats :: %{
          component: SpiderMan.component(),
          total: non_neg_integer,
          success: non_neg_integer,
          fail: non_neg_integer,
          duration_ms: non_neg_integer,
          tps: float
        }

  @doc false
  def attach_spider_stats(spider, tid) do
    name = inspect(spider)

    for event <- @events do
      id = {__MODULE__, event, self()}
      :telemetry.attach(id, event, &__MODULE__.update_spider_stats/4, {name, tid})
    end
  end

  @doc false
  def detach_spider_stats do
    for event <- @events do
      :telemetry.detach({__MODULE__, event, self()})
    end
  end

  @doc """
  Fetch spider's throughput infos

  Accept a spider or a spider's `stats_tid`, the infos are ordered by the message
  flow: `Downloader` -> `Spider` -> `ItemProcessor`.
  """
  @spec get_stats(SpiderMan.spider() | :ets.tid()) :: [component_stats]
  def get_stats(spider) when is_atom(spider) do
    SpiderMan.get_state(spider).stats_tid |> get_stats()
  end

  def get_stats(tid) do
    stats = :ets.tab2list(tid) |> Map.new(&{elem(&1, 0), &1})
    Enum.map(@components, &build_component_stats(Map.fetch!(stats, &1)))
  end

  @doc "Format spider's throughput infos to a printable string"
  @spec format_stats(SpiderMan.spider() | :ets.tid() | [component_stats]) :: String.t()
  def format_stats(stats) when is_list(stats) do
    Enum.map_join(stats, " ", &format_component_stats/1)
  end

  def format_stats(spider), do: get_stats(spider) |> format_stats()

  if Mix.env() != :test do
    @doc "Print spider's throughput infos to the console"
    @spec print_stats([component_stats]) :: :ok
    def print_stats(stats), do: IO.write("\e[2K\r#{format_stats(stats)} ")
  else
    @doc false
    def print_stats(stats), do: format_stats(stats)
  end

  defp build_component_stats({component, total, success, fail, duration}) do
    duration_ms = System.convert_time_unit(duration, :native, :millisecond)

    tps =
      case duration_ms do
        0 -> 0.0
        ms -> Float.floor(success / (ms / 1000), 2)
      end

    %{
      component: component,
      total: total,
      success: success,
      fail: fail,
      duration_ms: duration_ms,
      tps: tps
    }
  end

  defp format_component_stats(%{component: component} = stats) do
    tps = if stats.tps > 999, do: "999+", else: stats.tps
    component = Atom.to_string(component) |> Macro.camelize()
    "#{component}:[#{stats.success}/#{stats.total} #{tps}/s F:#{stats.fail}]"
  end

  @doc false
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
    SpiderMan.Stats.get_stats(tid) |> state.callback.()
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
