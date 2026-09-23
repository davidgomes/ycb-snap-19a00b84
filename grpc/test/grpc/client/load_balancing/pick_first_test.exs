defmodule GRPC.Client.LoadBalancing.PickFirstTest do
  use ExUnit.Case, async: true

  alias GRPC.Channel
  alias GRPC.Client.LoadBalancing.PickFirst

  defp channels(hosts), do: Enum.map(hosts, &%Channel{host: &1, port: 50051})

  test "init/1 returns an error without channels" do
    assert {:error, :no_channels} = PickFirst.init(channels: [])
  end

  test "pick/1 always returns the first channel" do
    {:ok, state} = PickFirst.init(channels: channels(["a", "b"]))

    assert {:ok, %Channel{host: "a"}} = PickFirst.pick(state)
    assert {:ok, %Channel{host: "a"}} = PickFirst.pick(state)
  end

  test "pick/1 works from processes other than the table owner" do
    {:ok, state} = PickFirst.init(channels: channels(["a", "b"]))

    assert {:ok, %Channel{host: "a"}} = Task.await(Task.async(fn -> PickFirst.pick(state) end))
  end

  test "update/2 switches to the first channel of the new set" do
    {:ok, state} = PickFirst.init(channels: channels(["a", "b"]))
    {:ok, state} = PickFirst.update(state, channels(["b", "c"]))

    assert {:ok, %Channel{host: "b"}} = PickFirst.pick(state)
  end

  test "pick/1 returns an error after updating to no channels" do
    {:ok, state} = PickFirst.init(channels: channels(["a"]))
    {:ok, state} = PickFirst.update(state, [])

    assert {:error, :no_channels} = PickFirst.pick(state)
  end

  test "shutdown/1 deletes the table and is idempotent" do
    {:ok, %{tid: tid} = state} = PickFirst.init(channels: channels(["a"]))

    assert :ok = PickFirst.shutdown(state)
    assert :ets.info(tid) == :undefined
    assert :ok = PickFirst.shutdown(state)
  end
end
