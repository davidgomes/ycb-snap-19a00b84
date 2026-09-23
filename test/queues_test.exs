defmodule Oban.Console.QueuesTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Oban.Console.Queues

  describe "list/0" do
    test "returns the state of every configured queue" do
      expect(Oban, :config, fn ->
        %Oban.Config{queues: [default: [limit: 10], mailer: [limit: 5]]}
      end)

      expect(Oban, :check_queue, 2, fn [queue: name] ->
        %{queue: to_string(name), paused: name == :mailer, local_limit: 10, running: []}
      end)

      assert [
               %{queue: "default", paused: false, local_limit: 10},
               %{queue: "mailer", paused: true, local_limit: 10}
             ] = Queues.list()
    end

    test "returns empty without configured queues" do
      expect(Oban, :config, fn -> %Oban.Config{queues: []} end)
      reject(&Oban.check_queue/1)

      assert [] = Queues.list()
    end
  end

  describe "pause_queues/1" do
    test "pauses a single queue" do
      expect(Oban, :pause_queue, fn [queue: "default"] -> :ok end)

      assert {:ok, "default"} = Queues.pause_queues("default")
    end

    test "pauses a list of queues" do
      expect(Oban, :pause_queue, fn [queue: "default"] -> :ok end)
      expect(Oban, :pause_queue, fn [queue: "mailer"] -> :ok end)

      assert [{:ok, "default"}, {:ok, "mailer"}] = Queues.pause_queues(["default", "mailer"])
    end

    test "does nothing with an empty list" do
      reject(&Oban.pause_queue/1)

      assert [] = Queues.pause_queues([])
    end

    test "returns error with an invalid queue name" do
      reject(&Oban.pause_queue/1)

      assert {:error, 123, "Queue name is not valid"} = Queues.pause_queues(123)
    end
  end

  describe "resume_queues/1" do
    test "resumes a single queue" do
      expect(Oban, :resume_queue, fn [queue: "default"] -> :ok end)

      assert {:ok, "default"} = Queues.resume_queues("default")
    end

    test "resumes a list of queues" do
      expect(Oban, :resume_queue, fn [queue: "default"] -> :ok end)
      expect(Oban, :resume_queue, fn [queue: "mailer"] -> :ok end)

      assert [{:ok, "default"}, {:ok, "mailer"}] = Queues.resume_queues(["default", "mailer"])
    end

    test "does nothing with an empty list" do
      reject(&Oban.resume_queue/1)

      assert [] = Queues.resume_queues([])
    end

    test "returns error with an invalid queue name" do
      reject(&Oban.resume_queue/1)

      assert {:error, nil, "Queue name is not valid"} = Queues.resume_queues(nil)
    end
  end
end
