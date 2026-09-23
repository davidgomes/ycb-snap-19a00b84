defmodule Oban.Console.QueuesTest do
  use ExUnit.Case, async: true
  use Mimic

  import ExUnit.CaptureIO

  alias Oban.Console.Queues

  describe "list/0" do
    test "returns only queue, paused and local_limit of each configured queue" do
      stub_queues()

      assert Queues.list() == [
               %{queue: "default", paused: false, local_limit: 10},
               %{queue: "mailers", paused: true, local_limit: 20}
             ]
    end

    test "returns empty without queues configured" do
      stub(Oban, :config, fn -> %Oban.Config{queues: []} end)
      reject(&Oban.check_queue/1)

      assert [] = Queues.list()
    end
  end

  describe "show_list/0" do
    test "prints a table with the queues" do
      stub_queues()

      output = capture(fn -> assert :ok = Queues.show_list() end)

      assert output == """

             ----------------------------------
             | queue   | paused | local_limit |
             ----------------------------------
             | default | false  | 10          |
             | mailers | true   | 20          |
             ----------------------------------
             """
    end

    test "prints no records found without queues configured" do
      stub(Oban, :config, fn -> %Oban.Config{queues: []} end)
      reject(&Oban.check_queue/1)

      output = capture(fn -> assert :ok = Queues.show_list() end)

      assert output == "\nNo records found\n"
    end
  end

  describe "pause_queues/1" do
    test "pauses a queue" do
      expect(Oban, :pause_queue, fn [queue: "default"] -> :ok end)

      output = capture(fn -> assert :ok = Queues.pause_queues("default") end)

      assert output == "Paused | default\n"
    end

    test "pauses each queue of the list" do
      Oban
      |> expect(:pause_queue, fn [queue: "default"] -> :ok end)
      |> expect(:pause_queue, fn [queue: "mailers"] -> :ok end)

      output = capture(fn -> assert :ok = Queues.pause_queues(["default", "mailers"]) end)

      assert output == "Paused | default\nPaused | mailers\n"
    end

    test "does nothing with an empty list" do
      reject(&Oban.pause_queue/1)

      assert capture(fn -> assert :ok = Queues.pause_queues([]) end) == ""
    end

    test "doesn't pause an invalid queue name" do
      reject(&Oban.pause_queue/1)

      output = capture(fn -> assert :ok = Queues.pause_queues(1) end)

      assert output == "Pause | 1 | Queue name is not valid\n"
    end

    test "pauses only the valid queue names of the list" do
      expect(Oban, :pause_queue, fn [queue: "default"] -> :ok end)

      output = capture(fn -> assert :ok = Queues.pause_queues([1, "default"]) end)

      assert output == "Pause | 1 | Queue name is not valid\nPaused | default\n"
    end
  end

  describe "resume_queues/1" do
    test "resumes a queue" do
      expect(Oban, :resume_queue, fn [queue: "default"] -> :ok end)

      output = capture(fn -> assert :ok = Queues.resume_queues("default") end)

      assert output == "Resumed | default\n"
    end

    test "resumes each queue of the list" do
      Oban
      |> expect(:resume_queue, fn [queue: "default"] -> :ok end)
      |> expect(:resume_queue, fn [queue: "mailers"] -> :ok end)

      output = capture(fn -> assert :ok = Queues.resume_queues(["default", "mailers"]) end)

      assert output == "Resumed | default\nResumed | mailers\n"
    end

    test "does nothing with an empty list" do
      reject(&Oban.resume_queue/1)

      assert capture(fn -> assert :ok = Queues.resume_queues([]) end) == ""
    end

    test "doesn't resume an invalid queue name" do
      reject(&Oban.resume_queue/1)

      output = capture(fn -> assert :ok = Queues.resume_queues(1) end)

      assert output == "Resume | 1 | Queue name is not valid\n"
    end

    test "resumes only the valid queue names of the list" do
      expect(Oban, :resume_queue, fn [queue: "default"] -> :ok end)

      output = capture(fn -> assert :ok = Queues.resume_queues([1, "default"]) end)

      assert output == "Resume | 1 | Queue name is not valid\nResumed | default\n"
    end
  end

  defp stub_queues() do
    stub(Oban, :config, fn ->
      %Oban.Config{queues: [default: [limit: 10], mailers: [limit: 20]]}
    end)

    stub(Oban, :check_queue, fn
      [queue: :default] -> queue_state("default", false, 10)
      [queue: :mailers] -> queue_state("mailers", true, 20)
    end)
  end

  defp queue_state(queue, paused, local_limit) do
    %{
      queue: queue,
      paused: paused,
      local_limit: local_limit,
      node: "worker.1",
      running: [],
      uuid: "4b1ee1b5-7c6e-4a64-9b5f-0f2b9b6b4b1e"
    }
  end

  defp capture(fun), do: fun |> capture_io() |> String.replace(~r/\e\[[0-9;]*m/, "")
end
