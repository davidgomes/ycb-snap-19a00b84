defmodule SpiderMan.StatsTest do
  use ExUnit.Case, async: true
  alias SpiderMan.{CommonSpider, Requester.JustReturn, Stats, Utils}

  test "get_stats & format_stats" do
    tid = :ets.new(:stats, [:set, :public])
    duration = System.convert_time_unit(2000, :millisecond, :native)

    :ets.insert(tid, [
      {:downloader, 10, 8, 1, duration},
      {:spider, 8, 8, 0, 0},
      {:item_processor, 0, 0, 0, 0}
    ])

    assert [
             %{component: :downloader, total: 10, success: 8, fail: 1, duration: 2000, tps: 4.0},
             %{component: :spider, total: 8, success: 8, fail: 0, duration: 0, tps: 0},
             %{component: :item_processor, total: 0, success: 0, fail: 0, duration: 0, tps: 0}
           ] = stats = Stats.get_stats(tid)

    assert "Downloader:[8/10 4.0/s F:1] Spider:[8/8 0/s F:0] ItemProcessor:[0/0 0/s F:0]" =
             Stats.format_stats(stats)

    assert Stats.format_stats(stats) == Stats.print_spider_stats(tid, true)

    parent = self()
    Stats.print_spider_stats(tid, &send(parent, {:stats, &1}))
    assert_received {:stats, ^stats}
  end

  test "print_stats with fun" do
    parent = self()
    spider = :print_stats_with_fun

    assert {:ok, _pid} =
             CommonSpider.start(
               spider,
               [handle_response: fn _response, _context -> %{} end],
               log2file: false,
               print_stats: &send(parent, {:stats, &1}),
               downloader_options: [requester: JustReturn],
               item_processor_options: [storage: false]
             )

    on_exit(fn -> SpiderMan.stop(spider) end)
    assert SpiderMan.insert_request(spider, Utils.build_request("1"))

    assert_receive {:stats,
                    [
                      %{component: :downloader, total: 1, success: 1, fail: 0},
                      %{component: :spider, total: 1, success: 1, fail: 0},
                      %{component: :item_processor, total: 0, success: 0, fail: 0}
                    ]},
                   5000
  end
end
