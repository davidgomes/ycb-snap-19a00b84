defmodule Oban.Console.QueuesTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Oban.Console.Queues

  describe "get_queues/1" do
    test "returns the state of every configured queue" do
      Oban
      |> expect(:config, fn Oban -> %{queues: [default: [limit: 10], mailers: [limit: 5]]} end)
      |> expect(:check_queue, 2, fn Oban, [queue: queue] -> %{queue: to_string(queue)} end)

      assert [%{queue: "default"}, %{queue: "mailers"}] = Queues.get_queues()
    end

    test "returns empty when no queues are configured" do
      expect(Oban, :config, fn Oban -> %{queues: []} end)

      assert [] = Queues.get_queues()
    end
  end

  describe "pause_queues/2" do
    test "pauses each given queue" do
      expect(Oban, :pause_queue, 2, fn Oban, [queue: queue] ->
        send(self(), {:paused, queue})
        :ok
      end)

      Queues.pause_queues([:default, :mailers])

      assert_received {:paused, :default}
      assert_received {:paused, :mailers}
    end
  end

  describe "resume_queues/2" do
    test "resumes each given queue" do
      expect(Oban, :resume_queue, 2, fn Oban, [queue: queue] ->
        send(self(), {:resumed, queue})
        :ok
      end)

      Queues.resume_queues([:default, :mailers])

      assert_received {:resumed, :default}
      assert_received {:resumed, :mailers}
    end
  end
end
