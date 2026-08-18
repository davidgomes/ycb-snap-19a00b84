defmodule GRPC.Client.LoadBalancing.RoundRobinTest do
  use ExUnit.Case, async: true

  alias GRPC.Channel
  alias GRPC.Client.LoadBalancing.RoundRobin

  defp channels(hosts) do
    Enum.map(hosts, &%Channel{host: &1, port: 50051})
  end

  defp init(hosts) do
    {:ok, state} = RoundRobin.init(channels: channels(hosts))
    on_exit(fn -> RoundRobin.shutdown(state) end)
    state
  end

  defp pick_hosts(state, count) do
    for _ <- 1..count do
      {:ok, %Channel{host: host}} = RoundRobin.pick(state)
      host
    end
  end

  describe "init/1" do
    test "creates a table owned by the calling process" do
      %{table: table} = init(["10.0.0.1"])

      assert :ets.info(table, :owner) == self()
    end

    test "accepts an empty channel set" do
      assert {:ok, state} = RoundRobin.init(channels: [])
      assert {:error, :no_channels} = RoundRobin.pick(state)
    end
  end

  describe "pick/1" do
    test "starts at the first channel and rotates in order" do
      state = init(["10.0.0.1", "10.0.0.2", "10.0.0.3"])

      assert pick_hosts(state, 7) == [
               "10.0.0.1",
               "10.0.0.2",
               "10.0.0.3",
               "10.0.0.1",
               "10.0.0.2",
               "10.0.0.3",
               "10.0.0.1"
             ]
    end

    test "keeps returning the only channel there is" do
      state = init(["10.0.0.1"])

      assert pick_hosts(state, 5) == List.duplicate("10.0.0.1", 5)
    end

    test "rotates evenly under concurrent picks" do
      hosts = ["10.0.0.1", "10.0.0.2", "10.0.0.3", "10.0.0.4"]
      state = init(hosts)

      pickers = 16
      picks_per_picker = 250

      counts =
        1..pickers
        |> Task.async_stream(fn _ -> pick_hosts(state, picks_per_picker) end,
          max_concurrency: pickers,
          ordered: false
        )
        |> Enum.flat_map(fn {:ok, picked} -> picked end)
        |> Enum.frequencies()

      expected = div(pickers * picks_per_picker, length(hosts))

      assert counts == Map.new(hosts, &{&1, expected})
    end

    test "returns an error instead of crashing once the table is gone" do
      {:ok, state} = RoundRobin.init(channels: channels(["10.0.0.1"]))
      :ok = RoundRobin.shutdown(state)

      assert {:error, :no_channels} = RoundRobin.pick(state)
    end

    test "survives a cursor that has wrapped around" do
      state = init(["10.0.0.1", "10.0.0.2"])

      # Unsigned atomics wrap to 0 on overflow: picks either side of that must stay in
      # range and keep rotating.
      :atomics.put(state.cursor, 1, Bitwise.bsl(1, 64) - 1)

      assert pick_hosts(state, 3) == ["10.0.0.2", "10.0.0.1", "10.0.0.2"]
    end
  end

  describe "update/2" do
    test "replaces the channel set and restarts the rotation" do
      state = init(["10.0.0.1", "10.0.0.2"])

      assert pick_hosts(state, 1) == ["10.0.0.1"]

      :ok = RoundRobin.update(state, channels(["10.0.0.7", "10.0.0.8"]))

      assert pick_hosts(state, 3) == ["10.0.0.7", "10.0.0.8", "10.0.0.7"]
    end

    test "keeps the state published to callers unchanged" do
      state = init(["10.0.0.1"])

      :ok = RoundRobin.update(state, channels(["10.0.0.2", "10.0.0.3"]))

      assert %{table: table, cursor: cursor} = state
      assert :ets.info(table) != :undefined
      assert :atomics.info(cursor).size == 1
    end

    test "an empty set makes picks fail" do
      state = init(["10.0.0.1"])

      :ok = RoundRobin.update(state, [])

      assert {:error, :no_channels} = RoundRobin.pick(state)
    end
  end

  describe "shutdown/1" do
    test "frees the table and is idempotent" do
      {:ok, %{table: table} = state} = RoundRobin.init(channels: channels(["10.0.0.1"]))

      assert :ok = RoundRobin.shutdown(state)
      assert :ets.info(table) == :undefined
      assert :ok = RoundRobin.shutdown(state)
    end
  end
end
