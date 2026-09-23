defmodule Oban.Console.QueuesTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Oban.Console.Queues

  describe "list/0" do
    test "returns empty without queues configured" do
      stub(Oban, :config, fn -> %Oban.Config{queues: []} end)

      assert [] = Queues.list()
    end

    test "returns configured queues state" do
      stub(Oban, :config, fn ->
        %Oban.Config{queues: [default: [limit: 10], mailer: [limit: 5]]}
      end)

      stub(Oban, :check_queue, fn [queue: name] ->
        %{
          queue: to_string(name),
          paused: name == :mailer,
          local_limit: if(name == :default, do: 10, else: 5),
          node: "node@host",
          running: []
        }
      end)

      assert [
               %{queue: "default", paused: false, local_limit: 10},
               %{queue: "mailer", paused: true, local_limit: 5}
             ] = Queues.list()
    end
  end

  describe "pause_queues/1" do
    test "pauses a queue" do
      expect(Oban, :pause_queue, fn [queue: "default"] -> :ok end)

      assert {:ok, "default"} = Queues.pause_queues("default")
    end

    test "pauses multiple queues" do
      expect(Oban, :pause_queue, 2, fn [queue: _] -> :ok end)

      assert [{:ok, "default"}, {:ok, "mailer"}] = Queues.pause_queues(["default", "mailer"])
    end

    test "does nothing with empty list" do
      reject(&Oban.pause_queue/1)

      assert [] = Queues.pause_queues([])
    end

    test "returns error with invalid queue name" do
      reject(&Oban.pause_queue/1)

      assert {:error, :default, "Queue name is not valid"} = Queues.pause_queues(:default)
    end
  end

  describe "resume_queues/1" do
    test "resumes a queue" do
      expect(Oban, :resume_queue, fn [queue: "default"] -> :ok end)

      assert {:ok, "default"} = Queues.resume_queues("default")
    end

    test "resumes multiple queues" do
      expect(Oban, :resume_queue, 2, fn [queue: _] -> :ok end)

      assert [{:ok, "default"}, {:ok, "mailer"}] = Queues.resume_queues(["default", "mailer"])
    end

    test "does nothing with empty list" do
      reject(&Oban.resume_queue/1)

      assert [] = Queues.resume_queues([])
    end

    test "returns error with invalid queue name" do
      reject(&Oban.resume_queue/1)

      assert {:error, :default, "Queue name is not valid"} = Queues.resume_queues(:default)
    end
  end
end
