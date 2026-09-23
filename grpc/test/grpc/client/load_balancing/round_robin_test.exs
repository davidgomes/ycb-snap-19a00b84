defmodule GRPC.Client.LoadBalancing.RoundRobinTest do
  use ExUnit.Case, async: true

  alias GRPC.Channel
  alias GRPC.Client.LoadBalancing.RoundRobin

  defp channel(host), do: %Channel{host: host, port: 50051}

  defp pick_hosts(state, n) do
    for _ <- 1..n do
      {:ok, %Channel{host: host}} = RoundRobin.pick(state)
      host
    end
  end

  describe "init/1" do
    test "returns {:error, :no_addresses} without channels" do
      assert {:error, :no_addresses} = RoundRobin.init(channels: [])
      assert {:error, :no_addresses} = RoundRobin.init([])
    end
  end

  describe "pick/1" do
    test "rotates through the channels in order, starting with the first" do
      {:ok, state} =
        RoundRobin.init(channels: [channel("10.0.0.1"), channel("10.0.0.2"), channel("10.0.0.3")])

      assert pick_hosts(state, 7) ==
               ~w(10.0.0.1 10.0.0.2 10.0.0.3 10.0.0.1 10.0.0.2 10.0.0.3 10.0.0.1)
    end

    test "keeps returning the only channel" do
      {:ok, state} = RoundRobin.init(channels: [channel("10.0.0.1")])

      assert pick_hosts(state, 3) == ~w(10.0.0.1 10.0.0.1 10.0.0.1)
    end

    test "spreads concurrent picks exactly evenly" do
      channels = [channel("10.0.0.1"), channel("10.0.0.2"), channel("10.0.0.3")]
      {:ok, state} = RoundRobin.init(channels: channels)

      procs = 16
      picks_per_proc = 300

      counts =
        1..procs
        |> Enum.map(fn _ -> Task.async(fn -> pick_hosts(state, picks_per_proc) end) end)
        |> Enum.flat_map(&Task.await/1)
        |> Enum.frequencies()

      expected = div(procs * picks_per_proc, length(channels))
      assert counts == %{"10.0.0.1" => expected, "10.0.0.2" => expected, "10.0.0.3" => expected}
    end
  end

  describe "update/2" do
    test "replaces the channels in place and restarts the rotation" do
      {:ok, state} = RoundRobin.init(channels: [channel("10.0.0.1"), channel("10.0.0.2")])
      assert pick_hosts(state, 1) == ~w(10.0.0.1)

      assert {:ok, ^state} = RoundRobin.update(state, [channel("10.0.0.3"), channel("10.0.0.4")])
      assert pick_hosts(state, 3) == ~w(10.0.0.3 10.0.0.4 10.0.0.3)
    end

    test "an empty channel list makes pick fail until channels come back" do
      {:ok, state} = RoundRobin.init(channels: [channel("10.0.0.1")])

      assert {:ok, ^state} = RoundRobin.update(state, [])
      assert {:error, :no_addresses} = RoundRobin.pick(state)

      assert {:ok, ^state} = RoundRobin.update(state, [channel("10.0.0.5")])
      assert pick_hosts(state, 2) == ~w(10.0.0.5 10.0.0.5)
    end
  end

  describe "shutdown/1" do
    test "deletes the table, picks then fail without raising" do
      {:ok, %{tid: tid} = state} = RoundRobin.init(channels: [channel("10.0.0.1")])

      assert :ok = RoundRobin.shutdown(state)
      assert :ets.info(tid) == :undefined
      assert {:error, :no_connection} = RoundRobin.pick(state)
    end

    test "is idempotent" do
      {:ok, state} = RoundRobin.init(channels: [channel("10.0.0.1")])

      assert :ok = RoundRobin.shutdown(state)
      assert :ok = RoundRobin.shutdown(state)
    end
  end
end
