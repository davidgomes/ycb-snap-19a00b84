defmodule Oban.Console.QueuesTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Oban.Console.Queues

  describe "list/0" do
    test "returns the state of each configured queue" do
      stub(Oban, :config, fn ->
        %Oban.Config{queues: [default: [limit: 10], mailers: [limit: 5]]}
      end)

      stub(Oban, :check_queue, fn
        [queue: :default] ->
          %{queue: "default", paused: false, local_limit: 10, running: [], node: "node"}

        [queue: :mailers] ->
          %{queue: "mailers", paused: true, local_limit: 5, running: [1], node: "node"}
      end)

      assert [
               %{queue: "default", paused: false, local_limit: 10},
               %{queue: "mailers", paused: true, local_limit: 5}
             ] = Queues.list()
    end

    test "returns only queue, paused and local_limit fields" do
      stub(Oban, :config, fn -> %Oban.Config{queues: [default: [limit: 10]]} end)

      stub(Oban, :check_queue, fn [queue: :default] ->
        %{queue: "default", paused: false, local_limit: 10, running: [], node: "node"}
      end)

      assert [queue] = Queues.list()
      assert [:local_limit, :paused, :queue] = queue |> Map.keys() |> Enum.sort()
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
      expect(Oban, :pause_queue, fn [queue: "default"] -> :ok end)
      expect(Oban, :pause_queue, fn [queue: "mailers"] -> :ok end)

      assert [{:ok, "default"}, {:ok, "mailers"}] = Queues.pause_queues(["default", "mailers"])
    end

    test "does nothing without queues" do
      reject(&Oban.pause_queue/1)

      assert [] = Queues.pause_queues([])
    end

    test "returns error for invalid queue names" do
      expect(Oban, :pause_queue, fn [queue: "default"] -> :ok end)

      assert {:error, nil, "Queue name is not valid"} = Queues.pause_queues(nil)

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
      expect(Oban, :resume_queue, fn [queue: "default"] -> :ok end)
      expect(Oban, :resume_queue, fn [queue: "mailers"] -> :ok end)

      assert [{:ok, "default"}, {:ok, "mailers"}] = Queues.resume_queues(["default", "mailers"])
    end

    test "does nothing without queues" do
      reject(&Oban.resume_queue/1)

      assert [] = Queues.resume_queues([])
    end

    test "returns error for invalid queue names" do
      expect(Oban, :resume_queue, fn [queue: "default"] -> :ok end)

      assert {:error, nil, "Queue name is not valid"} = Queues.resume_queues(nil)

      assert [{:ok, "default"}, {:error, 1, "Queue name is not valid"}] =
               Queues.resume_queues(["default", 1])
    end
  end
end
