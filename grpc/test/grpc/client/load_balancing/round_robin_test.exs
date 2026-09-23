defmodule GRPC.Client.LoadBalancing.RoundRobinTest do
  use ExUnit.Case, async: true

  alias GRPC.Channel
  alias GRPC.Client.LoadBalancing.RoundRobin

  defp channels(hosts), do: Enum.map(hosts, &%Channel{host: &1, port: 50051})

  defp pick_hosts(state, n) do
    for _ <- 1..n do
      {:ok, %Channel{host: host}, ^state} = RoundRobin.pick(state)
      host
    end
  end

  test "init/1 returns an error without channels" do
    assert {:error, :no_addresses} = RoundRobin.init(channels: [])
    assert {:error, :no_addresses} = RoundRobin.init([])
  end

  test "pick/1 cycles through channels in order" do
    {:ok, state} = RoundRobin.init(channels: channels(["a", "b", "c"]))

    assert pick_hosts(state, 7) == ["a", "b", "c", "a", "b", "c", "a"]
  end

  test "pick/1 is safe to call concurrently from many processes" do
    {:ok, state} = RoundRobin.init(channels: channels(["a", "b"]))

    hosts =
      1..100
      |> Task.async_stream(fn _ -> pick_hosts(state, 10) end)
      |> Enum.flat_map(fn {:ok, hosts} -> hosts end)

    assert Enum.frequencies(hosts) == %{"a" => 500, "b" => 500}
  end

  test "update/2 replaces channels in place and restarts the rotation" do
    {:ok, state} = RoundRobin.init(channels: channels(["a", "b"]))
    assert pick_hosts(state, 1) == ["a"]

    assert {:ok, ^state} = RoundRobin.update(state, channels(["c", "d", "e"]))
    assert pick_hosts(state, 4) == ["c", "d", "e", "c"]
  end

  test "pick/1 returns an error after update/2 with no channels" do
    {:ok, state} = RoundRobin.init(channels: channels(["a"]))
    {:ok, state} = RoundRobin.update(state, [])

    assert {:error, :no_addresses} = RoundRobin.pick(state)
  end

  test "pick/1 returns an error once terminated" do
    {:ok, state} = RoundRobin.init(channels: channels(["a"]))

    assert :ok = RoundRobin.terminate(state)
    assert :ok = RoundRobin.terminate(state)
    assert {:error, :no_addresses} = RoundRobin.pick(state)
  end
end
