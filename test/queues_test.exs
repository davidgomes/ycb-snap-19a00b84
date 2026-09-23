defmodule Oban.Console.QueuesTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Oban.Console.Queues

  describe "list/0" do
    test "returns configured queues with their state" do
      stub(Oban, :config, fn ->
        %Oban.Config{queues: [default: [limit: 10], mailers: [limit: 5]]}
      end)

      stub(Oban, :check_queue, fn [queue: name] ->
        %{queue: to_string(name), paused: name == :mailers, local_limit: 10, running: []}
      end)

      assert [
               %{queue: "default", paused: false, local_limit: 10},
               %{queue: "mailers", paused: true, local_limit: 10}
             ] = Queues.list()
    end

    test "returns empty without configured queues" do
      stub(Oban, :config, fn -> %Oban.Config{queues: []} end)
      reject(&Oban.check_queue/1)

      assert [] = Queues.list()
    end
  end

  describe "pause_queues/1" do
    test "pauses a queue" do
      expect(Oban, :pause_queue, fn [queue: "default"] -> :ok end)

      assert {:ok, "default"} = Queues.pause_queues("default")
    end

    test "pauses multiple queues" do
      expect(Oban, :pause_queue, 2, fn [queue: _] -> :ok end)

      assert [{:ok, "default"}, {:ok, "mailers"}] = Queues.pause_queues(["default", "mailers"])
    end

    test "does nothing without queues" do
      reject(&Oban.pause_queue/1)

      assert [] = Queues.pause_queues([])
    end

    test "returns error for invalid queue name" do
      reject(&Oban.pause_queue/1)

      assert {:error, nil, "Queue name is not valid"} = Queues.pause_queues(nil)
    end

    test "pauses valid queues and returns error for invalid ones" do
      expect(Oban, :pause_queue, fn [queue: "default"] -> :ok end)

      assert [{:ok, "default"}, {:error, 1, "Queue name is not valid"}] =
               Queues.pause_queues(["default", 1])
    end
  end

  describe "resume_queues/1" do
    test "resumes a queue" do
      expect(Oban, :resume_queue, fn [queue: "default"] -> :ok end)

      assert {:ok, "default"} = Queues.resume_queues("default")
    end

    test "resumes multiple queues" do
      expect(Oban, :resume_queue, 2, fn [queue: _] -> :ok end)

      assert [{:ok, "default"}, {:ok, "mailers"}] = Queues.resume_queues(["default", "mailers"])
    end

    test "does nothing without queues" do
      reject(&Oban.resume_queue/1)

      assert [] = Queues.resume_queues([])
    end

    test "returns error for invalid queue name" do
      reject(&Oban.resume_queue/1)

      assert {:error, nil, "Queue name is not valid"} = Queues.resume_queues(nil)
    end
  end
end
