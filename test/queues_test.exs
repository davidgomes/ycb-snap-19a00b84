defmodule Oban.Console.QueuesTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Oban.Console.Queues

  describe "get_queues/0" do
    test "returns the state of every configured queue sorted by name" do
      stub(Oban, :config, fn -> %Oban.Config{queues: [default: [limit: 10], alpha: [limit: 5]]} end)

      stub(Oban, :check_queue, fn [queue: queue] ->
        %{queue: to_string(queue), paused: false}
      end)

      assert [%{queue: "alpha"}, %{queue: "default"}] = Queues.get_queues()
    end

    test "returns empty list without queues" do
      stub(Oban, :config, fn -> %Oban.Config{queues: []} end)

      assert [] = Queues.get_queues()
    end
  end

  describe "pause_queues/1" do
    test "pauses each given queue" do
      Oban
      |> expect(:pause_queue, fn [queue: "default"] -> :ok end)
      |> expect(:pause_queue, fn [queue: "alpha"] -> :ok end)

      assert :ok = Queues.pause_queues(["default", "alpha"])
    end
  end

  describe "resume_queues/1" do
    test "resumes each given queue" do
      Oban
      |> expect(:resume_queue, fn [queue: "default"] -> :ok end)
      |> expect(:resume_queue, fn [queue: "alpha"] -> :ok end)

      assert :ok = Queues.resume_queues(["default", "alpha"])
    end
  end
end
