defmodule GRPC.Client.LoadBalancing.PickFirstTest do
  use ExUnit.Case, async: true

  alias GRPC.Channel
  alias GRPC.Client.LoadBalancing.PickFirst

  defp channels(hosts) do
    Enum.map(hosts, &%Channel{host: &1, port: 50051})
  end

  defp init(hosts) do
    {:ok, state} = PickFirst.init(channels: channels(hosts))
    on_exit(fn -> PickFirst.shutdown(state) end)
    state
  end

  describe "init/1" do
    test "creates a table owned by the calling process" do
      %{table: table} = init(["10.0.0.1"])

      assert :ets.info(table, :owner) == self()
    end

    test "accepts an empty channel set" do
      assert {:ok, state} = PickFirst.init(channels: [])
      assert {:error, :no_channels} = PickFirst.pick(state)
    end

    test "accepts no channel option at all" do
      assert {:ok, state} = PickFirst.init([])
      assert {:error, :no_channels} = PickFirst.pick(state)
    end
  end

  describe "pick/1" do
    test "always returns the first channel" do
      state = init(["10.0.0.1", "10.0.0.2", "10.0.0.3"])

      picks = for _ <- 1..10, do: PickFirst.pick(state)

      assert Enum.uniq(picks) == [{:ok, %Channel{host: "10.0.0.1", port: 50051}}]
    end

    test "returns an error instead of crashing once the table is gone" do
      {:ok, state} = PickFirst.init(channels: channels(["10.0.0.1"]))
      :ok = PickFirst.shutdown(state)

      assert {:error, :no_channels} = PickFirst.pick(state)
    end
  end

  describe "update/2" do
    test "replaces the channel set in place" do
      state = init(["10.0.0.1"])

      :ok = PickFirst.update(state, channels(["10.0.0.7", "10.0.0.8"]))

      assert {:ok, %Channel{host: "10.0.0.7"}} = PickFirst.pick(state)
    end

    test "an empty set makes picks fail" do
      state = init(["10.0.0.1"])

      :ok = PickFirst.update(state, [])

      assert {:error, :no_channels} = PickFirst.pick(state)
    end
  end

  describe "shutdown/1" do
    test "frees the table and is idempotent" do
      {:ok, %{table: table} = state} = PickFirst.init(channels: channels(["10.0.0.1"]))

      assert :ok = PickFirst.shutdown(state)
      assert :ets.info(table) == :undefined
      assert :ok = PickFirst.shutdown(state)
    end
  end
end
