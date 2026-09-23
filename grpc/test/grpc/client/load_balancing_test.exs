defmodule GRPC.Client.LoadBalancingTest do
  use ExUnit.Case, async: true

  alias GRPC.Channel
  alias GRPC.Client.LoadBalancing.PickFirst
  alias GRPC.Client.LoadBalancing.RoundRobin

  defp channels(hosts), do: Enum.map(hosts, &%Channel{host: &1, port: 50051})

  describe "PickFirst" do
    test "init/1 returns :no_addresses without channels" do
      assert {:error, :no_addresses} = PickFirst.init(channels: [])
      assert {:error, :no_addresses} = PickFirst.init([])
    end

    test "pick/1 always returns the first channel" do
      [first | _] = chs = channels(["10.0.0.1", "10.0.0.2"])
      {:ok, state} = PickFirst.init(channels: chs)

      for _ <- 1..5, do: assert({:ok, ^first} = PickFirst.pick(state))
    end

    test "update/2 replaces the picked channel in place" do
      {:ok, state} = PickFirst.init(channels: channels(["10.0.0.1"]))
      [new | _] = chs = channels(["10.0.0.9", "10.0.0.1"])

      assert :ok = PickFirst.update(state, chs)
      assert {:ok, ^new} = PickFirst.pick(state)
    end

    test "update/2 with no channels makes pick/1 fail until channels return" do
      [ch] = chs = channels(["10.0.0.1"])
      {:ok, state} = PickFirst.init(channels: chs)

      assert :ok = PickFirst.update(state, [])
      assert {:error, :no_channels} = PickFirst.pick(state)

      assert :ok = PickFirst.update(state, chs)
      assert {:ok, ^ch} = PickFirst.pick(state)
    end

    test "pick/1 is readable from other processes" do
      [ch] = chs = channels(["10.0.0.1"])
      {:ok, state} = PickFirst.init(channels: chs)

      assert {:ok, ^ch} = Task.async(fn -> PickFirst.pick(state) end) |> Task.await()
    end

    test "shutdown/1 deletes the table and pick/1 returns an error afterwards" do
      {:ok, %{tid: tid} = state} = PickFirst.init(channels: channels(["10.0.0.1"]))

      assert :ok = PickFirst.shutdown(state)
      assert :undefined == :ets.info(tid)
      assert {:error, :no_channels} = PickFirst.pick(state)
      assert :ok = PickFirst.shutdown(state)
    end
  end

  describe "RoundRobin" do
    test "init/1 returns :no_addresses without channels" do
      assert {:error, :no_addresses} = RoundRobin.init(channels: [])
      assert {:error, :no_addresses} = RoundRobin.init([])
    end

    test "pick/1 rotates through channels on every call" do
      chs = channels(["10.0.0.1", "10.0.0.2", "10.0.0.3"])
      {:ok, state} = RoundRobin.init(channels: chs)

      picks = for _ <- 1..6, do: elem(RoundRobin.pick(state), 1)

      assert picks == chs ++ chs
    end

    test "update/2 swaps the channel set and restarts the rotation" do
      {:ok, state} = RoundRobin.init(channels: channels(["10.0.0.1", "10.0.0.2"]))
      {:ok, _} = RoundRobin.pick(state)

      new_chs = channels(["10.0.0.3", "10.0.0.4"])
      assert :ok = RoundRobin.update(state, new_chs)

      picks = for _ <- 1..4, do: elem(RoundRobin.pick(state), 1)
      assert picks == new_chs ++ new_chs
    end

    test "update/2 with no channels makes pick/1 fail until channels return" do
      chs = channels(["10.0.0.1"])
      {:ok, state} = RoundRobin.init(channels: chs)

      assert :ok = RoundRobin.update(state, [])
      assert {:error, :no_channels} = RoundRobin.pick(state)

      assert :ok = RoundRobin.update(state, chs)
      assert {:ok, _} = RoundRobin.pick(state)
    end

    test "pick/1 keeps working when the counter wraps around" do
      chs = channels(["10.0.0.1", "10.0.0.2", "10.0.0.3"])
      {:ok, %{counter: counter} = state} = RoundRobin.init(channels: chs)

      :atomics.put(counter, 1, 0xFFFF_FFFF_FFFF_FFFF)

      for _ <- 1..4 do
        assert {:ok, %Channel{} = ch} = RoundRobin.pick(state)
        assert ch in chs
      end
    end

    test "concurrent picks are evenly distributed" do
      chs = channels(["10.0.0.1", "10.0.0.2", "10.0.0.3", "10.0.0.4"])
      {:ok, state} = RoundRobin.init(channels: chs)

      counts =
        1..16
        |> Task.async_stream(fn _ ->
          for _ <- 1..1_000, do: elem(RoundRobin.pick(state), 1).host
        end)
        |> Enum.flat_map(fn {:ok, hosts} -> hosts end)
        |> Enum.frequencies()

      assert Map.values(counts) == [4_000, 4_000, 4_000, 4_000]
    end

    test "shutdown/1 deletes the table and pick/1 returns an error afterwards" do
      {:ok, %{tid: tid} = state} = RoundRobin.init(channels: channels(["10.0.0.1"]))

      assert :ok = RoundRobin.shutdown(state)
      assert :undefined == :ets.info(tid)
      assert {:error, :no_channels} = RoundRobin.pick(state)
      assert :ok = RoundRobin.shutdown(state)
    end
  end
end
