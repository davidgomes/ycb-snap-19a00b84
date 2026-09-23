defmodule GRPC.Client.LoadBalancing.RoundRobinTest do
  use ExUnit.Case, async: true

  alias GRPC.Channel
  alias GRPC.Client.LoadBalancing.RoundRobin

  defp channels(pairs) do
    Enum.map(pairs, fn {host, port} -> %Channel{host: host, port: port, ref: {host, port}} end)
  end

  defp pick_hosts(state, count) do
    for _ <- 1..count do
      {:ok, %Channel{host: host}, ^state} = RoundRobin.pick(state)
      host
    end
  end

  describe "init/1" do
    test "stores the channels in an ETS table owned by the caller and a zeroed cursor" do
      {:ok, %{tid: tid, atomics: cursor}} = RoundRobin.init(channels: channels([{"a", 1}]))

      assert :ets.info(tid, :owner) == self()
      assert :ets.info(tid, :protection) == :protected
      assert :atomics.get(cursor, 1) == 0
    end

    test "returns :no_addresses for an empty or missing channel list" do
      assert {:error, :no_addresses} = RoundRobin.init(channels: [])
      assert {:error, :no_addresses} = RoundRobin.init([])
    end
  end

  describe "pick/1" do
    test "cycles through the channels in order, starting with the first" do
      {:ok, state} = RoundRobin.init(channels: channels([{"a", 1}, {"b", 2}, {"c", 3}]))

      assert pick_hosts(state, 7) == ["a", "b", "c", "a", "b", "c", "a"]
    end

    test "keeps returning the only channel of a single-channel list" do
      {:ok, state} = RoundRobin.init(channels: channels([{"only", 1}]))

      assert pick_hosts(state, 4) == ["only", "only", "only", "only"]
    end

    test "stays in range when the unsigned cursor wraps around" do
      {:ok, state} = RoundRobin.init(channels: channels([{"a", 1}, {"b", 2}, {"c", 3}]))
      :atomics.put(state.atomics, 1, 0xFFFF_FFFF_FFFF_FFFF)

      assert Enum.sort(pick_hosts(state, 3)) == ["a", "b", "c"]
    end

    test "returns :no_addresses instead of raising once the table is gone" do
      {:ok, state} = RoundRobin.init(channels: channels([{"a", 1}]))
      :ets.delete(state.tid)

      assert {:error, :no_addresses} = RoundRobin.pick(state)
    end

    test "spreads concurrent picks evenly across channels" do
      {:ok, state} = RoundRobin.init(channels: channels(for i <- 1..4, do: {"host#{i}", i}))

      picks =
        1..16
        |> Enum.map(fn _ -> Task.async(fn -> pick_hosts(state, 250) end) end)
        |> Enum.flat_map(&Task.await/1)

      assert Enum.frequencies(picks) == %{
               "host1" => 1000,
               "host2" => 1000,
               "host3" => 1000,
               "host4" => 1000
             }
    end
  end

  describe "update/2" do
    test "replaces the channels in place and restarts from the first one" do
      {:ok, state} = RoundRobin.init(channels: channels([{"a", 1}, {"b", 2}]))
      pick_hosts(state, 3)

      assert {:ok, ^state} = RoundRobin.update(state, channels([{"x", 9}, {"y", 8}, {"z", 7}]))
      assert pick_hosts(state, 4) == ["x", "y", "z", "x"]
    end

    test "an empty list makes picks fail until channels come back" do
      {:ok, state} = RoundRobin.init(channels: channels([{"a", 1}]))

      {:ok, state} = RoundRobin.update(state, [])
      assert {:error, :no_addresses} = RoundRobin.pick(state)

      {:ok, state} = RoundRobin.update(state, channels([{"b", 2}]))
      assert pick_hosts(state, 2) == ["b", "b"]
    end
  end
end
