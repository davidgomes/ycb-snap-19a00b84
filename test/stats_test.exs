defmodule SpiderMan.StatsTest do
  use ExUnit.Case, async: true
  alias SpiderMan.{CommonSpider, Requester, Stats, Utils}

  setup do
    spider = :"stats_test_#{System.unique_integer([:positive])}"
    on_exit(fn -> SpiderMan.stop(spider) end)
    [spider: spider]
  end

  defp start_spider(spider, settings) do
    handle_response = fn _response, _context -> %{} end

    CommonSpider.start(
      spider,
      [handle_response: handle_response],
      [
        downloader_options: [pipelines: [], requester: Requester.JustReturn],
        spider_options: [pipelines: []],
        item_processor_options: [pipelines: [], storage: false]
      ] ++ settings
    )
  end

  defp wait_for_success(spider, component, count, retries \\ 20) do
    info = SpiderMan.throughput(spider) |> Enum.find(&(&1.component == component))

    cond do
      info.success >= count ->
        info

      retries > 0 ->
        Process.sleep(50)
        wait_for_success(spider, component, count, retries - 1)

      true ->
        flunk("expected #{count} success for #{component}, got: #{inspect(info)}")
    end
  end

  test "throughput of a new spider", %{spider: spider} do
    assert {:ok, _} = start_spider(spider, [])

    zero = %{total: 0, success: 0, fail: 0, duration: 0, tps: 0.0}

    assert [
             Map.put(zero, :component, :downloader),
             Map.put(zero, :component, :spider),
             Map.put(zero, :component, :item_processor)
           ] == SpiderMan.throughput(spider)
  end

  test "collect throughput even though print_stats is false", %{spider: spider} do
    assert {:ok, _} = start_spider(spider, print_stats: false)
    assert %{stats_task_pid: nil} = SpiderMan.get_state(spider)

    SpiderMan.insert_requests(spider, Utils.build_requests(1..5))

    assert %{component: :downloader, total: 5, success: 5, fail: 0} =
             wait_for_success(spider, :downloader, 5)

    assert %{component: :spider, total: 5, success: 5, fail: 0} =
             wait_for_success(spider, :spider, 5)
  end

  test "print_stats with fun/1", %{spider: spider} do
    parent = self()
    print_stats = fn throughput -> send(parent, {:throughput, throughput}) end
    assert {:ok, _} = start_spider(spider, print_stats: print_stats)

    SpiderMan.insert_requests(spider, Utils.build_requests(1..3))
    wait_for_success(spider, :spider, 3)

    assert_receive {:throughput, [downloader, _spider, _item_processor]}, 3000
    assert %{component: :downloader, total: 3, success: 3, fail: 0, tps: tps} = downloader
    assert is_float(tps)
  end

  test "print_stats fun/1 failed would not crash the spider", %{spider: spider} do
    parent = self()

    print_stats = fn _throughput ->
      send(parent, :printed)
      raise "boom"
    end

    assert {:ok, pid} = start_spider(spider, print_stats: print_stats)
    assert_receive :printed, 3000
    assert_receive :printed, 2000
    assert Process.alive?(pid)
    assert %{stats_task_pid: stats_task_pid} = SpiderMan.get_state(spider)
    assert Process.alive?(stats_task_pid)
  end

  test "format throughput for printing" do
    tid = :ets.new(:stats, [:set, :public])
    duration = System.convert_time_unit(2000, :millisecond, :native)

    :ets.insert(tid, [
      {:downloader, 10, 8, 2, duration},
      {:spider, 8, 8, 0, 0},
      {:item_processor, 0, 0, 0, 0}
    ])

    assert [
             %{component: :downloader, total: 10, success: 8, fail: 2, duration: 2000, tps: 4.0},
             %{component: :spider, total: 8, success: 8, fail: 0, duration: 0, tps: 0.0},
             %{component: :item_processor, total: 0, success: 0, fail: 0, duration: 0, tps: 0.0}
           ] = Stats.get_throughput(tid)

    assert "Downloader:[8/10 4.0/s F:2] Spider:[8/8 0.0/s F:0] ItemProcessor:[0/0 0.0/s F:0]" =
             Stats.print_spider_stats(tid, true)
  end
end
