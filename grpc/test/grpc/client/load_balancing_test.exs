defmodule GRPC.Client.LoadBalancingTest do
  use ExUnit.Case, async: true

  alias GRPC.Channel
  alias GRPC.Client.LoadBalancing.{PickFirst, RoundRobin}

  defp channels(hosts), do: Enum.map(hosts, &%Channel{host: &1, port: 50051})

  describe "PickFirst" do
    test "always picks the first channel" do
      {:ok, state} = PickFirst.init(channels: channels(["a", "b"]))

      for _ <- 1..3, do: assert({:ok, %Channel{host: "a"}} = PickFirst.pick(state))
    end

    test "update replaces the channel set" do
      {:ok, state} = PickFirst.init(channels: channels(["a"]))

      :ok = PickFirst.update(state, channels(["b", "c"]))
      assert {:ok, %Channel{host: "b"}} = PickFirst.pick(state)

      :ok = PickFirst.update(state, [])
      assert {:error, :no_channels} = PickFirst.pick(state)
    end
  end

  describe "RoundRobin" do
    test "cycles through channels on every pick" do
      {:ok, state} = RoundRobin.init(channels: channels(["a", "b", "c"]))

      hosts = for _ <- 1..6, do: elem(RoundRobin.pick(state), 1).host
      assert hosts == ["a", "b", "c", "a", "b", "c"]
    end

    test "returns an error when there are no channels" do
      {:ok, state} = RoundRobin.init(channels: [])
      assert {:error, :no_channels} = RoundRobin.pick(state)
    end

    test "update to a smaller set only yields current channels" do
      {:ok, state} = RoundRobin.init(channels: channels(["a", "b", "c"]))
      for _ <- 1..2, do: RoundRobin.pick(state)

      :ok = RoundRobin.update(state, channels(["x"]))

      for _ <- 1..3, do: assert({:ok, %Channel{host: "x"}} = RoundRobin.pick(state))
    end

    test "picks are evenly distributed across concurrent callers" do
      {:ok, state} = RoundRobin.init(channels: channels(["a", "b"]))

      counts =
        1..100
        |> Task.async_stream(fn _ -> elem(RoundRobin.pick(state), 1).host end)
        |> Enum.map(fn {:ok, host} -> host end)
        |> Enum.frequencies()

      assert counts == %{"a" => 50, "b" => 50}
    end

    test "shutdown deletes the table" do
      {:ok, %{tid: tid} = state} = RoundRobin.init(channels: channels(["a"]))

      assert :ok = RoundRobin.shutdown(state)
      assert :ets.info(tid) == :undefined
    end
  end
end
