defmodule GRPC.Client.LoadBalancing.RoundRobinTest do
  use ExUnit.Case, async: true

  alias GRPC.Channel
  alias GRPC.Client.LoadBalancing.RoundRobin

  defp channels(pairs),
    do: Enum.map(pairs, fn {h, p} -> %Channel{host: h, port: p, ref: {h, p}} end)

  describe "init/1" do
    test "creates an ETS table and an atomic index" do
      {:ok, state} = RoundRobin.init(channels: channels([{"a", 1}, {"b", 2}]))
      assert %{tid: tid, atomics: atomic} = state
      assert is_reference(tid)
      assert :ets.info(tid) != :undefined
      assert :atomics.info(atomic) != :undefined
    end

    test "rejects empty channel lists" do
      assert {:error, :no_addresses} = RoundRobin.init(channels: [])
    end

    test "rejects missing :channels option" do
      assert {:error, :no_addresses} = RoundRobin.init([])
    end
  end

  describe "pick/1" do
    test "rotates across channels sequentially and wraps" do
      {:ok, state} =
        RoundRobin.init(channels: channels([{"a", 1}, {"b", 2}, {"c", 3}]))

      picks =
        for _ <- 1..6 do
          {:ok, ch, _} = RoundRobin.pick(state)
          {ch.host, ch.port}
        end

      assert picks == [
               {"a", 1},
               {"b", 2},
               {"c", 3},
               {"a", 1},
               {"b", 2},
               {"c", 3}
             ]
    end

    test "returns :no_addresses after update/2 empties the table" do
      {:ok, state} = RoundRobin.init(channels: channels([{"a", 1}]))
      {:ok, _} = RoundRobin.update(state, [])
      assert {:error, :no_addresses} = RoundRobin.pick(state)
    end

    test "returns :no_addresses instead of raising when the table was deleted" do
      {:ok, state} = RoundRobin.init(channels: channels([{"a", 1}]))
      :ets.delete(state.tid)
      assert {:error, :no_addresses} = RoundRobin.pick(state)
    end

    test "is safe under concurrent callers without dropping or crashing" do
      {:ok, state} =
        RoundRobin.init(channels: channels([{"a", 1}, {"b", 2}, {"c", 3}]))

      task_count = 20
      picks_per_task = 50

      tasks =
        for _ <- 1..task_count do
          Task.async(fn ->
            for _ <- 1..picks_per_task do
              assert {:ok, %Channel{}, _} = RoundRobin.pick(state)
            end
          end)
        end

      Enum.each(tasks, &Task.await(&1, 5000))
    end
  end

  describe "update/2" do
    test "updates channel set in place and resets size" do
      {:ok, state} = RoundRobin.init(channels: channels([{"a", 1}, {"b", 2}]))
      {:ok, ch1, _} = RoundRobin.pick(state)
      assert ch1.host == "a"

      {:ok, new_state} =
        RoundRobin.update(state, channels([{"x", 10}, {"y", 20}, {"z", 30}]))

      assert new_state.tid == state.tid
      assert new_state.atomics == state.atomics

      # Next pick comes from the new set
      {:ok, next_ch, _} = RoundRobin.pick(new_state)
      assert next_ch.host in ["x", "y", "z"]
    end

    test "emptying the pool returns empty on subsequent picks" do
      {:ok, state} = RoundRobin.init(channels: channels([{"a", 1}]))
      {:ok, state} = RoundRobin.update(state, [])
      assert {:error, :no_addresses} = RoundRobin.pick(state)
    end
  end
end
