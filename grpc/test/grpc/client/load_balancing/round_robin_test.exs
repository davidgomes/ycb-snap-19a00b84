defmodule GRPC.Client.LoadBalancing.RoundRobinTest do
  use ExUnit.Case, async: true

  alias GRPC.Channel
  alias GRPC.Client.LoadBalancing.RoundRobin

  defp channel(host), do: %Channel{host: host, port: 50051}

  defp channels(n), do: Enum.map(1..n, &channel("10.0.0.#{&1}"))

  defp picked_hosts(state, count) do
    for _ <- 1..count do
      {:ok, %Channel{host: host}} = RoundRobin.pick(state)
      host
    end
  end

  test "init/1 returns :no_addresses without channels" do
    assert {:error, :no_addresses} = RoundRobin.init(channels: [])
    assert {:error, :no_addresses} = RoundRobin.init([])
  end

  test "pick/1 cycles through every channel in order" do
    {:ok, state} = RoundRobin.init(channels: channels(3))

    [a, b, c, a2, b2, c2] = picked_hosts(state, 6)

    assert Enum.sort([a, b, c]) == ["10.0.0.1", "10.0.0.2", "10.0.0.3"]
    assert [a2, b2, c2] == [a, b, c]
  end

  test "a single channel is always picked" do
    {:ok, state} = RoundRobin.init(channels: channels(1))

    assert Enum.uniq(picked_hosts(state, 5)) == ["10.0.0.1"]
  end

  test "update/2 replaces the rotation without changing the state" do
    {:ok, state} = RoundRobin.init(channels: channels(2))

    assert :ok = RoundRobin.update(state, [channel("10.0.0.7"), channel("10.0.0.8")])

    assert picked_hosts(state, 4) |> Enum.frequencies() ==
             %{"10.0.0.7" => 2, "10.0.0.8" => 2}
  end

  test "pick/1 returns :no_connection after updating to no channels, and recovers" do
    {:ok, state} = RoundRobin.init(channels: channels(2))

    assert :ok = RoundRobin.update(state, [])
    assert {:error, :no_connection} = RoundRobin.pick(state)

    assert :ok = RoundRobin.update(state, [channel("10.0.0.9")])
    assert picked_hosts(state, 3) == ["10.0.0.9", "10.0.0.9", "10.0.0.9"]
  end

  test "shutdown/1 frees the table and later picks return :no_connection" do
    {:ok, %{tid: tid} = state} = RoundRobin.init(channels: channels(2))

    assert :ok = RoundRobin.shutdown(state)
    assert :ets.info(tid) == :undefined
    assert {:error, :no_connection} = RoundRobin.pick(state)
    assert :ok = RoundRobin.shutdown(state)
  end

  test "concurrent pickers share the rotation evenly" do
    n_channels = 4
    n_procs = 16
    picks_per_proc = 1_000
    {:ok, state} = RoundRobin.init(channels: channels(n_channels))

    counts =
      1..n_procs
      |> Enum.map(fn _ -> Task.async(fn -> picked_hosts(state, picks_per_proc) end) end)
      |> Enum.flat_map(&Task.await/1)
      |> Enum.frequencies()

    expected = div(n_procs * picks_per_proc, n_channels)
    assert map_size(counts) == n_channels
    assert Enum.all?(counts, fn {_host, count} -> count == expected end)
  end
end
