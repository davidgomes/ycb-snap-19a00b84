defmodule GRPC.Client.LoadBalancing.PickFirstTest do
  use ExUnit.Case, async: true

  alias GRPC.Channel
  alias GRPC.Client.LoadBalancing.PickFirst

  defp channel(host), do: %Channel{host: host, port: 50051}

  test "init/1 returns :no_addresses without channels" do
    assert {:error, :no_addresses} = PickFirst.init(channels: [])
    assert {:error, :no_addresses} = PickFirst.init([])
  end

  test "pick/1 always returns the first channel" do
    [first, _second] = channels = [channel("10.0.0.1"), channel("10.0.0.2")]
    {:ok, state} = PickFirst.init(channels: channels)

    for _ <- 1..5, do: assert({:ok, ^first} = PickFirst.pick(state))
  end

  test "update/2 switches picks to the new first channel without changing the state" do
    {:ok, state} = PickFirst.init(channels: [channel("10.0.0.1")])
    replacement = channel("10.0.0.2")

    assert :ok = PickFirst.update(state, [replacement, channel("10.0.0.3")])
    assert {:ok, ^replacement} = PickFirst.pick(state)
  end

  test "pick/1 returns :no_connection after updating to no channels, and recovers" do
    {:ok, state} = PickFirst.init(channels: [channel("10.0.0.1")])

    assert :ok = PickFirst.update(state, [])
    assert {:error, :no_connection} = PickFirst.pick(state)

    recovered = channel("10.0.0.2")
    assert :ok = PickFirst.update(state, [recovered])
    assert {:ok, ^recovered} = PickFirst.pick(state)
  end

  test "pick/1 works from processes other than the table owner" do
    first = channel("10.0.0.1")
    {:ok, state} = PickFirst.init(channels: [first])

    assert {:ok, ^first} = Task.async(fn -> PickFirst.pick(state) end) |> Task.await()
  end

  test "shutdown/1 frees the table and later picks return :no_connection" do
    {:ok, %{tid: tid} = state} = PickFirst.init(channels: [channel("10.0.0.1")])

    assert :ok = PickFirst.shutdown(state)
    assert :ets.info(tid) == :undefined
    assert {:error, :no_connection} = PickFirst.pick(state)
    assert :ok = PickFirst.shutdown(state)
  end
end
