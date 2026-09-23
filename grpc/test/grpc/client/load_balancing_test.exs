defmodule GRPC.Client.LoadBalancingTest do
  use ExUnit.Case, async: true

  alias GRPC.Channel
  alias GRPC.Client.LoadBalancing.PickFirst
  alias GRPC.Client.LoadBalancing.RoundRobin

  defp channels(hosts), do: Enum.map(hosts, &%Channel{host: &1, port: 50051})

  describe "PickFirst" do
    test "init/1 fails without channels" do
      assert {:error, :no_addresses} = PickFirst.init(channels: [])
    end

    test "pick/1 always returns the first channel" do
      [first | _] = chs = channels(["a", "b"])
      {:ok, state} = PickFirst.init(channels: chs)

      for _ <- 1..3, do: assert({:ok, ^first, ^state} = PickFirst.pick(state))
    end

    test "update/2 swaps the channel in place and empties on []" do
      {:ok, state} = PickFirst.init(channels: channels(["a"]))
      [b] = channels(["b"])

      assert {:ok, ^state} = PickFirst.update(state, [b])
      assert {:ok, ^b, _} = PickFirst.pick(state)

      assert {:ok, ^state} = PickFirst.update(state, [])
      assert {:error, :no_addresses} = PickFirst.pick(state)
    end

    test "pick/1 returns an error after terminate/1" do
      {:ok, state} = PickFirst.init(channels: channels(["a"]))
      assert :ok = PickFirst.terminate(state)
      assert {:error, :no_addresses} = PickFirst.pick(state)
      assert :ok = PickFirst.terminate(state)
    end
  end

  describe "RoundRobin" do
    test "init/1 fails without channels" do
      assert {:error, :no_addresses} = RoundRobin.init(channels: [])
    end

    test "pick/1 cycles through channels on every call" do
      {:ok, state} = RoundRobin.init(channels: channels(["a", "b", "c"]))

      hosts =
        for _ <- 1..6 do
          {:ok, ch, ^state} = RoundRobin.pick(state)
          ch.host
        end

      assert hosts == ["a", "b", "c", "a", "b", "c"]
    end

    test "pick/1 is shared across processes" do
      {:ok, state} = RoundRobin.init(channels: channels(["a", "b"]))

      hosts =
        1..10
        |> Task.async_stream(fn _ ->
          {:ok, ch, _} = RoundRobin.pick(state)
          ch.host
        end)
        |> Enum.map(fn {:ok, host} -> host end)

      assert Enum.frequencies(hosts) == %{"a" => 5, "b" => 5}
    end

    test "update/2 replaces the channel set and restarts the rotation" do
      {:ok, state} = RoundRobin.init(channels: channels(["a", "b"]))
      {:ok, _, _} = RoundRobin.pick(state)

      assert {:ok, ^state} = RoundRobin.update(state, channels(["x", "y"]))
      assert {:ok, %Channel{host: "x"}, _} = RoundRobin.pick(state)
      assert {:ok, %Channel{host: "y"}, _} = RoundRobin.pick(state)

      assert {:ok, ^state} = RoundRobin.update(state, [])
      assert {:error, :no_addresses} = RoundRobin.pick(state)
    end

    test "pick/1 returns an error after terminate/1" do
      {:ok, state} = RoundRobin.init(channels: channels(["a"]))
      assert :ok = RoundRobin.terminate(state)
      assert {:error, :no_addresses} = RoundRobin.pick(state)
    end
  end
end
