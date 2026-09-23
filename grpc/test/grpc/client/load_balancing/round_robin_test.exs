defmodule GRPC.Client.LoadBalancing.RoundRobinTest do
  use ExUnit.Case, async: true

  alias GRPC.Channel
  alias GRPC.Client.LoadBalancing.RoundRobin

  defp channels(hosts), do: Enum.map(hosts, &%Channel{host: &1, port: 50051})

  defp pick_hosts(state, count) do
    for _ <- 1..count do
      {:ok, %Channel{host: host}} = RoundRobin.pick(state)
      host
    end
  end

  test "init/1 returns an error without channels" do
    assert {:error, :no_channels} = RoundRobin.init(channels: [])
  end

  test "pick/1 cycles through channels in order" do
    {:ok, state} = RoundRobin.init(channels: channels(["a", "b", "c"]))

    assert pick_hosts(state, 6) == ["a", "b", "c", "a", "b", "c"]
  end

  test "pick/1 works from processes other than the table owner" do
    {:ok, state} = RoundRobin.init(channels: channels(["a", "b"]))

    hosts =
      1..4
      |> Task.async_stream(fn _ -> pick_hosts(state, 25) end)
      |> Enum.flat_map(fn {:ok, hosts} -> hosts end)

    assert Enum.frequencies(hosts) == %{"a" => 50, "b" => 50}
  end

  test "update/2 replaces the channel set" do
    {:ok, state} = RoundRobin.init(channels: channels(["a", "b"]))
    {:ok, state} = RoundRobin.update(state, channels(["c"]))

    assert pick_hosts(state, 2) == ["c", "c"]
  end

  test "pick/1 returns an error after updating to no channels" do
    {:ok, state} = RoundRobin.init(channels: channels(["a"]))
    {:ok, state} = RoundRobin.update(state, [])

    assert {:error, :no_channels} = RoundRobin.pick(state)
  end

  test "shutdown/1 deletes the table and is idempotent" do
    {:ok, %{tid: tid} = state} = RoundRobin.init(channels: channels(["a"]))

    assert :ok = RoundRobin.shutdown(state)
    assert :ets.info(tid) == :undefined
    assert :ok = RoundRobin.shutdown(state)
  end
end
