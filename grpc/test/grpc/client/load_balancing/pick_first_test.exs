defmodule GRPC.Client.LoadBalancing.PickFirstTest do
  use ExUnit.Case, async: true

  alias GRPC.Channel
  alias GRPC.Client.LoadBalancing.PickFirst

  defp channels(hosts), do: Enum.map(hosts, &%Channel{host: &1, port: 50051})

  test "init/1 returns an error without channels" do
    assert {:error, :no_addresses} = PickFirst.init(channels: [])
  end

  test "pick/1 always returns the first channel" do
    {:ok, state} = PickFirst.init(channels: channels(["a", "b"]))

    for _ <- 1..3 do
      assert {:ok, %Channel{host: "a"}, ^state} = PickFirst.pick(state)
    end
  end

  test "pick/1 can be called from a process other than the owner" do
    {:ok, state} = PickFirst.init(channels: channels(["a"]))

    assert {:ok, %Channel{host: "a"}, ^state} =
             Task.async(fn -> PickFirst.pick(state) end) |> Task.await()
  end

  test "update/2 switches to the new first channel in place" do
    {:ok, state} = PickFirst.init(channels: channels(["a", "b"]))

    assert {:ok, ^state} = PickFirst.update(state, channels(["b", "c"]))
    assert {:ok, %Channel{host: "b"}, ^state} = PickFirst.pick(state)
  end

  test "pick/1 returns an error after update/2 with no channels" do
    {:ok, state} = PickFirst.init(channels: channels(["a"]))
    {:ok, state} = PickFirst.update(state, [])

    assert {:error, :no_addresses} = PickFirst.pick(state)

    {:ok, state} = PickFirst.update(state, channels(["b"]))
    assert {:ok, %Channel{host: "b"}, ^state} = PickFirst.pick(state)
  end

  test "pick/1 returns an error once terminated" do
    {:ok, state} = PickFirst.init(channels: channels(["a"]))

    assert :ok = PickFirst.terminate(state)
    assert {:error, :no_addresses} = PickFirst.pick(state)
  end
end
