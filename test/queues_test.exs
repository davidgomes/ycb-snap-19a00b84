defmodule Oban.Console.QueuesTest do
  use ExUnit.Case, async: true
  use Mimic

  import ExUnit.CaptureIO

  alias Oban.Console.Queues

  describe "list/0" do
    test "returns the state of each configured queue" do
      expect(Oban, :config, fn ->
        %Oban.Config{queues: [default: [limit: 10], mailers: [limit: 5]]}
      end)

      expect(Oban, :check_queue, 2, fn
        [queue: :default] -> queue_check("default", false, 10)
        [queue: :mailers] -> queue_check("mailers", true, 5)
      end)

      assert Queues.list() == [
               %{queue: "default", paused: false, local_limit: 10},
               %{queue: "mailers", paused: true, local_limit: 5}
             ]
    end

    test "returns empty without queues configured" do
      expect(Oban, :config, fn -> %Oban.Config{queues: []} end)
      reject(Oban, :check_queue, 1)

      assert [] = Queues.list()
    end
  end

  describe "show_list/0" do
    test "prints a table with the queues" do
      expect(Oban, :config, fn ->
        %Oban.Config{queues: [default: [limit: 10], mailers: [limit: 5]]}
      end)

      expect(Oban, :check_queue, 2, fn
        [queue: :default] -> queue_check("default", false, 10)
        [queue: :mailers] -> queue_check("mailers", true, 5)
      end)

      output = capture_io(fn -> Queues.show_list() end) |> strip_ansi()

      assert output =~ "| queue   | paused | local_limit |"
      assert output =~ "| default | false  | 10          |"
      assert output =~ "| mailers | true   | 5           |"
    end

    test "prints a message without queues configured" do
      expect(Oban, :config, fn -> %Oban.Config{queues: []} end)

      assert capture_io(fn -> Queues.show_list() end) =~ "No records found"
    end
  end

  describe "pause_queues/1" do
    test "pauses a queue" do
      expect(Oban, :pause_queue, fn [queue: "default"] -> :ok end)

      output = capture_io(fn -> assert :ok = Queues.pause_queues("default") end)

      assert strip_ansi(output) == "Paused | default\n"
    end

    test "pauses each queue in the list" do
      expect(Oban, :pause_queue, 2, fn
        [queue: "default"] -> :ok
        [queue: "mailers"] -> :ok
      end)

      output = capture_io(fn -> assert :ok = Queues.pause_queues(["default", "mailers"]) end)

      assert strip_ansi(output) == "Paused | default\nPaused | mailers\n"
    end

    test "does nothing with an empty list" do
      reject(Oban, :pause_queue, 1)

      assert capture_io(fn -> assert :ok = Queues.pause_queues([]) end) == ""
    end

    test "doesn't pause an invalid queue name" do
      reject(Oban, :pause_queue, 1)

      output = capture_io(fn -> Queues.pause_queues([123]) end)

      assert strip_ansi(output) == "Pause | 123 | Queue name is not valid\n"
    end
  end

  describe "resume_queues/1" do
    test "resumes a queue" do
      expect(Oban, :resume_queue, fn [queue: "default"] -> :ok end)

      output = capture_io(fn -> assert :ok = Queues.resume_queues("default") end)

      assert strip_ansi(output) == "Resumed | default\n"
    end

    test "resumes each queue in the list" do
      expect(Oban, :resume_queue, 2, fn
        [queue: "default"] -> :ok
        [queue: "mailers"] -> :ok
      end)

      output = capture_io(fn -> assert :ok = Queues.resume_queues(["default", "mailers"]) end)

      assert strip_ansi(output) == "Resumed | default\nResumed | mailers\n"
    end

    test "does nothing with an empty list" do
      reject(Oban, :resume_queue, 1)

      assert capture_io(fn -> assert :ok = Queues.resume_queues([]) end) == ""
    end

    test "doesn't resume an invalid queue name" do
      reject(Oban, :resume_queue, 1)

      output = capture_io(fn -> Queues.resume_queues([123]) end)

      assert strip_ansi(output) == "Resume | 123 | Queue name is not valid\n"
    end
  end

  defp queue_check(queue, paused, local_limit) do
    %{
      queue: queue,
      paused: paused,
      local_limit: local_limit,
      node: "worker.1",
      running: [],
      started_at: ~U[2024-01-01 00:00:00Z],
      updated_at: ~U[2024-01-01 00:00:00Z]
    }
  end

  defp strip_ansi(text), do: String.replace(text, ~r/\e\[[0-9;]*m/, "")
end
