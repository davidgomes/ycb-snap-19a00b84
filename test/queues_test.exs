defmodule Oban.Console.QueuesTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Oban.Console.Queues

  describe "list/0" do
    test "returns the state of every configured queue" do
      expect(Oban, :config, fn ->
        %Oban.Config{queues: [default: [limit: 10], mailers: [limit: 5]]}
      end)

      expect(Oban, :check_queue, 2, fn
        [queue: :default] ->
          %{queue: "default", paused: false, local_limit: 10, node: "node", uuid: "1"}

        [queue: :mailers] ->
          %{queue: "mailers", paused: true, local_limit: 5, node: "node", uuid: "2"}
      end)

      assert [
               %{queue: "default", paused: false, local_limit: 10},
               %{queue: "mailers", paused: true, local_limit: 5}
             ] == Queues.list()
    end

    test "returns empty without configured queues" do
      expect(Oban, :config, fn -> %Oban.Config{queues: []} end)
      reject(Oban, :check_queue, 1)

      assert [] == Queues.list()
    end
  end

  describe "pause_queues/1" do
    test "pauses a queue by name" do
      expect(Oban, :pause_queue, fn [queue: "default"] -> :ok end)

      assert {:ok, "default"} == Queues.pause_queues("default")
    end

    test "pauses every queue in the list" do
      expect(Oban, :pause_queue, fn [queue: "default"] -> :ok end)
      expect(Oban, :pause_queue, fn [queue: "mailers"] -> :ok end)

      assert [{:ok, "default"}, {:ok, "mailers"}] == Queues.pause_queues(["default", "mailers"])
    end

    test "does nothing with an empty list" do
      reject(Oban, :pause_queue, 1)

      assert [] == Queues.pause_queues([])
    end

    test "returns an error for an invalid queue name" do
      reject(Oban, :pause_queue, 1)

      assert {:error, nil, "Queue name is not valid"} == Queues.pause_queues(nil)
    end

    test "only pauses the valid names in the list" do
      expect(Oban, :pause_queue, fn [queue: "default"] -> :ok end)

      assert [{:ok, "default"}, {:error, 1, "Queue name is not valid"}] ==
               Queues.pause_queues(["default", 1])
    end
  end

  describe "resume_queues/1" do
    test "resumes a queue by name" do
      expect(Oban, :resume_queue, fn [queue: "default"] -> :ok end)

      assert {:ok, "default"} == Queues.resume_queues("default")
    end

    test "resumes every queue in the list" do
      expect(Oban, :resume_queue, fn [queue: "default"] -> :ok end)
      expect(Oban, :resume_queue, fn [queue: "mailers"] -> :ok end)

      assert [{:ok, "default"}, {:ok, "mailers"}] == Queues.resume_queues(["default", "mailers"])
    end

    test "does nothing with an empty list" do
      reject(Oban, :resume_queue, 1)

      assert [] == Queues.resume_queues([])
    end

    test "returns an error for an invalid queue name" do
      reject(Oban, :resume_queue, 1)

      assert {:error, nil, "Queue name is not valid"} == Queues.resume_queues(nil)
    end

    test "only resumes the valid names in the list" do
      expect(Oban, :resume_queue, fn [queue: "default"] -> :ok end)

      assert [{:ok, "default"}, {:error, 1, "Queue name is not valid"}] ==
               Queues.resume_queues(["default", 1])
    end
  end
end
