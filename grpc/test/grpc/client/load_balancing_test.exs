defmodule GRPC.Client.LoadBalancingTest do
  use ExUnit.Case, async: true

  alias GRPC.Channel
  alias GRPC.Client.LoadBalancing.PickFirst
  alias GRPC.Client.LoadBalancing.RoundRobin

  defp channels(hosts), do: Enum.map(hosts, &%Channel{host: &1, port: 50051})

  defp hosts(state, count) do
    Enum.map(1..count, fn _ ->
      {:ok, %Channel{host: host}} = state.mod.pick(state.lb)
      host
    end)
  end

  defp start(mod, hosts) do
    {:ok, lb} = mod.init(channels: channels(hosts))
    on_exit(fn -> mod.stop(lb) end)

    %{mod: mod, lb: lb}
  end

  describe "PickFirst" do
    test "init/1 refuses an empty channel set" do
      assert {:error, :no_channels} = PickFirst.init(channels: [])
      assert {:error, :no_channels} = PickFirst.init([])
    end

    test "pick/1 always returns the first channel" do
      state = start(PickFirst, ["10.0.0.1", "10.0.0.2", "10.0.0.3"])

      assert hosts(state, 4) == ["10.0.0.1", "10.0.0.1", "10.0.0.1", "10.0.0.1"]
    end

    test "update/2 swaps the channel set in place" do
      state = start(PickFirst, ["10.0.0.1"])

      assert :ok = PickFirst.update(state.lb, channels(["10.0.0.7", "10.0.0.8"]))

      assert hosts(state, 2) == ["10.0.0.7", "10.0.0.7"]
    end

    test "pick/1 fails while no channel is ready" do
      state = start(PickFirst, ["10.0.0.1"])

      assert :ok = PickFirst.update(state.lb, [])
      assert {:error, :no_connection} = PickFirst.pick(state.lb)

      assert :ok = PickFirst.update(state.lb, channels(["10.0.0.1"]))
      assert hosts(state, 1) == ["10.0.0.1"]
    end

    test "stop/1 frees the table and later picks fail instead of raising" do
      {:ok, lb} = PickFirst.init(channels: channels(["10.0.0.1"]))

      assert :ok = PickFirst.stop(lb)
      assert :ets.info(lb.table) == :undefined
      assert {:error, :no_connection} = PickFirst.pick(lb)
      assert {:error, :no_connection} = PickFirst.update(lb, channels(["10.0.0.2"]))
      assert :ok = PickFirst.stop(lb)
    end

    test "concurrent picks all see the same channel" do
      state = start(PickFirst, ["10.0.0.1", "10.0.0.2"])

      picked =
        1..16
        |> Enum.map(fn _ -> Task.async(fn -> hosts(state, 100) end) end)
        |> Task.await_many(5_000)
        |> List.flatten()
        |> Enum.uniq()

      assert picked == ["10.0.0.1"]
    end
  end

  describe "RoundRobin" do
    test "init/1 refuses an empty channel set" do
      assert {:error, :no_channels} = RoundRobin.init(channels: [])
      assert {:error, :no_channels} = RoundRobin.init([])
    end

    test "pick/1 rotates over the channel set and wraps around" do
      state = start(RoundRobin, ["10.0.0.1", "10.0.0.2", "10.0.0.3"])

      assert hosts(state, 7) == [
               "10.0.0.1",
               "10.0.0.2",
               "10.0.0.3",
               "10.0.0.1",
               "10.0.0.2",
               "10.0.0.3",
               "10.0.0.1"
             ]
    end

    test "pick/1 keeps returning the only channel" do
      state = start(RoundRobin, ["10.0.0.1"])

      assert hosts(state, 3) == ["10.0.0.1", "10.0.0.1", "10.0.0.1"]
    end

    test "update/2 swaps the channel set and rewinds the cursor" do
      state = start(RoundRobin, ["10.0.0.1", "10.0.0.2"])

      assert hosts(state, 1) == ["10.0.0.1"]
      assert :ok = RoundRobin.update(state.lb, channels(["10.0.0.7", "10.0.0.8"]))

      assert hosts(state, 3) == ["10.0.0.7", "10.0.0.8", "10.0.0.7"]
    end

    test "update/2 to a smaller set never picks a dropped channel" do
      state = start(RoundRobin, ["10.0.0.1", "10.0.0.2", "10.0.0.3"])

      assert :ok = RoundRobin.update(state.lb, channels(["10.0.0.2"]))

      assert hosts(state, 3) == ["10.0.0.2", "10.0.0.2", "10.0.0.2"]
    end

    test "pick/1 fails while no channel is ready" do
      state = start(RoundRobin, ["10.0.0.1"])

      assert :ok = RoundRobin.update(state.lb, [])
      assert {:error, :no_connection} = RoundRobin.pick(state.lb)

      assert :ok = RoundRobin.update(state.lb, channels(["10.0.0.1"]))
      assert hosts(state, 1) == ["10.0.0.1"]
    end

    test "stop/1 frees the table and later picks fail instead of raising" do
      {:ok, lb} = RoundRobin.init(channels: channels(["10.0.0.1"]))

      assert :ok = RoundRobin.stop(lb)
      assert :ets.info(lb.table) == :undefined
      assert {:error, :no_connection} = RoundRobin.pick(lb)
      assert {:error, :no_connection} = RoundRobin.update(lb, channels(["10.0.0.2"]))
      assert :ok = RoundRobin.stop(lb)
    end

    test "16 concurrent processes share the rotation evenly" do
      state = start(RoundRobin, ["10.0.0.1", "10.0.0.2", "10.0.0.3", "10.0.0.4"])

      frequencies =
        1..16
        |> Enum.map(fn _ -> Task.async(fn -> hosts(state, 250) end) end)
        |> Task.await_many(10_000)
        |> List.flatten()
        |> Enum.frequencies()

      assert frequencies == %{
               "10.0.0.1" => 1_000,
               "10.0.0.2" => 1_000,
               "10.0.0.3" => 1_000,
               "10.0.0.4" => 1_000
             }
    end

    test "picks racing an update always return a channel of one of the two sets" do
      state = start(RoundRobin, ["10.0.0.1", "10.0.0.2"])

      pickers = Enum.map(1..8, fn _ -> Task.async(fn -> hosts(state, 500) end) end)

      Enum.each(1..20, fn _ ->
        :ok = RoundRobin.update(state.lb, channels(["10.0.0.7", "10.0.0.8"]))
        :ok = RoundRobin.update(state.lb, channels(["10.0.0.1", "10.0.0.2"]))
      end)

      picked = pickers |> Task.await_many(10_000) |> List.flatten() |> Enum.uniq() |> Enum.sort()

      assert picked -- ["10.0.0.1", "10.0.0.2", "10.0.0.7", "10.0.0.8"] == []
    end

    test "picks racing a stop return an error instead of raising" do
      {:ok, lb} = RoundRobin.init(channels: channels(["10.0.0.1", "10.0.0.2"]))

      pickers =
        for _ <- 1..8 do
          Task.async(fn ->
            Enum.each(1..500, fn _ -> RoundRobin.pick(lb) end)
            :done
          end)
        end

      :ok = RoundRobin.stop(lb)

      assert Enum.all?(Task.await_many(pickers, 10_000), &(&1 == :done))
    end
  end
end
