defmodule GRPC.Client.LoadBalancing.PickFirstTest do
  use ExUnit.Case, async: true

  alias GRPC.Channel
  alias GRPC.Client.LoadBalancing.PickFirst

  defp channels(pairs) do
    Enum.map(pairs, fn {host, port} -> %Channel{host: host, port: port, ref: {host, port}} end)
  end

  describe "init/1" do
    test "stores the channels in an ETS table owned by the caller" do
      {:ok, %{tid: tid}} = PickFirst.init(channels: channels([{"a", 1}, {"b", 2}]))

      assert :ets.info(tid, :owner) == self()
      assert :ets.info(tid, :protection) == :protected
    end

    test "returns :no_addresses for an empty or missing channel list" do
      assert {:error, :no_addresses} = PickFirst.init(channels: [])
      assert {:error, :no_addresses} = PickFirst.init([])
    end
  end

  describe "pick/1" do
    test "always returns the first channel and the unchanged state" do
      {:ok, state} = PickFirst.init(channels: channels([{"a", 1}, {"b", 2}]))

      for _ <- 1..3 do
        assert {:ok, %Channel{host: "a", port: 1}, ^state} = PickFirst.pick(state)
      end
    end

    test "is readable from processes other than the table owner" do
      {:ok, state} = PickFirst.init(channels: channels([{"a", 1}]))

      task = Task.async(fn -> PickFirst.pick(state) end)

      assert {:ok, %Channel{host: "a"}, _} = Task.await(task)
    end

    test "returns :no_addresses instead of raising once the table is gone" do
      {:ok, state} = PickFirst.init(channels: channels([{"a", 1}]))
      :ets.delete(state.tid)

      assert {:error, :no_addresses} = PickFirst.pick(state)
    end
  end

  describe "update/2" do
    test "switches to the first new channel in place" do
      {:ok, state} = PickFirst.init(channels: channels([{"a", 1}]))

      assert {:ok, ^state} = PickFirst.update(state, channels([{"x", 9}, {"y", 8}]))
      assert {:ok, %Channel{host: "x", port: 9}, _} = PickFirst.pick(state)
    end

    test "an empty list makes picks fail until channels come back" do
      {:ok, state} = PickFirst.init(channels: channels([{"a", 1}]))

      {:ok, state} = PickFirst.update(state, [])
      assert {:error, :no_addresses} = PickFirst.pick(state)

      {:ok, state} = PickFirst.update(state, channels([{"b", 2}]))
      assert {:ok, %Channel{host: "b"}, _} = PickFirst.pick(state)
    end
  end
end
