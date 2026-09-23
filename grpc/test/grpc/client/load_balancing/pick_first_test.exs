defmodule GRPC.Client.LoadBalancing.PickFirstTest do
  use ExUnit.Case, async: true

  alias GRPC.Channel
  alias GRPC.Client.LoadBalancing.PickFirst

  defp channel(host), do: %Channel{host: host, port: 50051}

  describe "init/1" do
    test "returns {:error, :no_addresses} without channels" do
      assert {:error, :no_addresses} = PickFirst.init(channels: [])
      assert {:error, :no_addresses} = PickFirst.init([])
    end
  end

  describe "pick/1" do
    test "always returns the first channel" do
      {:ok, state} = PickFirst.init(channels: [channel("10.0.0.1"), channel("10.0.0.2")])

      for _ <- 1..5 do
        assert {:ok, %Channel{host: "10.0.0.1"}} = PickFirst.pick(state)
      end
    end

    test "is callable from processes other than the owner" do
      {:ok, state} = PickFirst.init(channels: [channel("10.0.0.1")])

      assert {:ok, %Channel{host: "10.0.0.1"}} =
               Task.async(fn -> PickFirst.pick(state) end) |> Task.await()
    end
  end

  describe "update/2" do
    test "switches to the first of the new channels in place" do
      {:ok, state} = PickFirst.init(channels: [channel("10.0.0.1")])

      assert {:ok, ^state} = PickFirst.update(state, [channel("10.0.0.2"), channel("10.0.0.3")])
      assert {:ok, %Channel{host: "10.0.0.2"}} = PickFirst.pick(state)
    end

    test "an empty channel list makes pick fail until channels come back" do
      {:ok, state} = PickFirst.init(channels: [channel("10.0.0.1")])

      assert {:ok, ^state} = PickFirst.update(state, [])
      assert {:error, :no_addresses} = PickFirst.pick(state)

      assert {:ok, ^state} = PickFirst.update(state, [channel("10.0.0.4")])
      assert {:ok, %Channel{host: "10.0.0.4"}} = PickFirst.pick(state)
    end
  end

  describe "shutdown/1" do
    test "deletes the table, picks then fail without raising" do
      {:ok, %{tid: tid} = state} = PickFirst.init(channels: [channel("10.0.0.1")])

      assert :ok = PickFirst.shutdown(state)
      assert :ets.info(tid) == :undefined
      assert {:error, :no_connection} = PickFirst.pick(state)
    end

    test "is idempotent" do
      {:ok, state} = PickFirst.init(channels: [channel("10.0.0.1")])

      assert :ok = PickFirst.shutdown(state)
      assert :ok = PickFirst.shutdown(state)
    end
  end
end
