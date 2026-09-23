defmodule Oban.Console.QueuesTest do
  use ExUnit.Case, async: true
  use Mimic

  import ExUnit.CaptureIO

  alias Oban.Console.Queues
  alias Oban.Console.View.Printer

  describe "list/0" do
    setup :stub_configured_queues

    test "returns the state of each configured queue" do
      assert [
               %{queue: "default", paused: false, local_limit: 10},
               %{queue: "mailers", paused: true, local_limit: 5}
             ] == Queues.list()
    end

    test "returns empty without configured queues" do
      stub(Oban, :config, fn -> %Oban.Config{queues: []} end)
      reject(&Oban.check_queue/1)

      assert [] == Queues.list()
    end
  end

  describe "show_list/0" do
    setup :stub_configured_queues

    test "prints a table with the configured queues" do
      output = capture_io(fn -> Queues.show_list() end)

      assert """

             ----------------------------------
             | queue   | paused | local_limit |
             ----------------------------------
             | default | false  | 10          |
             | mailers | true   | 5           |
             ----------------------------------
             """ == strip_ansi(output)
    end

    test "prints no records found without configured queues" do
      stub(Oban, :config, fn -> %Oban.Config{queues: []} end)

      assert "\nNo records found\n" == capture_io(fn -> Queues.show_list() end)
    end
  end

  describe "pause_queues/1" do
    test "pauses each queue" do
      Oban
      |> expect(:pause_queue, fn [queue: "default"] -> :ok end)
      |> expect(:pause_queue, fn [queue: "mailers"] -> :ok end)

      {result, output} = with_io(fn -> Queues.pause_queues(["default", "mailers"]) end)

      assert :ok == result
      assert output =~ Printer.title(["Paused", "default"])
      assert output =~ Printer.title(["Paused", "mailers"])
    end

    test "pauses a single queue" do
      expect(Oban, :pause_queue, fn [queue: "default"] -> :ok end)

      assert {:ok, Printer.title(["Paused", "default"]) <> "\n"} ==
               with_io(fn -> Queues.pause_queues("default") end)
    end

    test "does nothing without queues" do
      reject(&Oban.pause_queue/1)

      assert {:ok, ""} == with_io(fn -> Queues.pause_queues([]) end)
    end

    test "doesn't pause invalid queue names" do
      expect(Oban, :pause_queue, fn [queue: "default"] -> :ok end)

      output = capture_io(fn -> Queues.pause_queues([123, "default"]) end)

      assert output =~ Printer.title(["Pause", 123, "Queue name is not valid"])
      assert output =~ Printer.title(["Paused", "default"])
    end
  end

  describe "resume_queues/1" do
    test "resumes each queue" do
      Oban
      |> expect(:resume_queue, fn [queue: "default"] -> :ok end)
      |> expect(:resume_queue, fn [queue: "mailers"] -> :ok end)

      {result, output} = with_io(fn -> Queues.resume_queues(["default", "mailers"]) end)

      assert :ok == result
      assert output =~ Printer.title(["Resumed", "default"])
      assert output =~ Printer.title(["Resumed", "mailers"])
    end

    test "resumes a single queue" do
      expect(Oban, :resume_queue, fn [queue: "default"] -> :ok end)

      assert {:ok, Printer.title(["Resumed", "default"]) <> "\n"} ==
               with_io(fn -> Queues.resume_queues("default") end)
    end

    test "does nothing without queues" do
      reject(&Oban.resume_queue/1)

      assert {:ok, ""} == with_io(fn -> Queues.resume_queues([]) end)
    end

    test "doesn't resume invalid queue names" do
      expect(Oban, :resume_queue, fn [queue: "default"] -> :ok end)

      output = capture_io(fn -> Queues.resume_queues([123, "default"]) end)

      assert output =~ Printer.title(["Resume", 123, "Queue name is not valid"])
      assert output =~ Printer.title(["Resumed", "default"])
    end
  end

  defp stub_configured_queues(_context) do
    stub(Oban, :config, fn ->
      %Oban.Config{queues: [default: [limit: 10], mailers: [limit: 5]]}
    end)

    stub(Oban, :check_queue, fn
      [queue: :default] -> queue_state("default", false, 10)
      [queue: :mailers] -> queue_state("mailers", true, 5)
    end)

    :ok
  end

  defp queue_state(queue, paused, limit) do
    %{
      queue: queue,
      paused: paused,
      limit: limit,
      local_limit: limit,
      node: "worker@localhost",
      running: [],
      started_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end

  defp strip_ansi(text), do: String.replace(text, ~r/\e\[[0-9;]*m/, "")
end
