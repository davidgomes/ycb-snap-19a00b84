defmodule Oban.Console.QueuesTest do
  use ExUnit.Case, async: true
  use Mimic

  import ExUnit.CaptureIO

  alias Oban.Console.Queues
  alias Oban.Console.View.Printer

  @queues [default: [limit: 10], mailers: [limit: 5]]

  defp stub_queues(queues, paused \\ []) do
    stub(Oban, :config, fn -> %Oban.Config{queues: queues} end)

    stub(Oban, :check_queue, fn [queue: name] ->
      name = to_string(name)

      %{
        queue: name,
        paused: name in paused,
        local_limit: get_in(queues, [String.to_existing_atom(name), :limit]),
        node: "worker.1",
        running: [],
        uuid: "b1ec5f2e-2c35-4c55-a8a4-0bd0d3e5d6c4"
      }
    end)
  end

  describe "list/0" do
    test "returns the state of each configured queue" do
      stub_queues(@queues, ["mailers"])

      assert [
               %{queue: "default", paused: false, local_limit: 10},
               %{queue: "mailers", paused: true, local_limit: 5}
             ] = Queues.list()
    end

    test "returns only queue, paused and local_limit fields" do
      stub_queues(@queues)

      assert Enum.all?(Queues.list(), fn queue ->
               queue |> Map.keys() |> Enum.sort() == [:local_limit, :paused, :queue]
             end)
    end

    test "checks every configured queue" do
      stub(Oban, :config, fn -> %Oban.Config{queues: @queues} end)

      expect(Oban, :check_queue, 2, fn [queue: name] ->
        assert name in [:default, :mailers]

        %{queue: to_string(name), paused: false, local_limit: 1}
      end)

      assert length(Queues.list()) == 2
    end

    test "returns empty without queues configured" do
      stub_queues([])
      reject(Oban, :check_queue, 1)

      assert [] = Queues.list()
    end
  end

  describe "show_list/0" do
    test "prints a table with the queues" do
      stub_queues(@queues, ["mailers"])

      output = capture_io(fn -> Queues.show_list() end)

      assert output =~ "queue"
      assert output =~ "paused"
      assert output =~ "local_limit"
      assert output =~ "default"
      assert output =~ "mailers"
      assert output =~ IO.ANSI.red() <> "false"
      assert output =~ IO.ANSI.green() <> "true"
    end

    test "prints a message without queues configured" do
      stub_queues([])

      assert capture_io(fn -> Queues.show_list() end) =~ "No records found"
    end
  end

  describe "pause_queues/1" do
    test "pauses a queue by name" do
      expect(Oban, :pause_queue, fn [queue: "default"] -> :ok end)

      output = capture_io(fn -> assert :ok = Queues.pause_queues("default") end)

      assert output == Printer.title(["Paused", "default"]) <> "\n"
    end

    test "pauses each queue in the list" do
      expect(Oban, :pause_queue, fn [queue: "default"] -> :ok end)
      expect(Oban, :pause_queue, fn [queue: "mailers"] -> :ok end)

      output = capture_io(fn -> assert :ok = Queues.pause_queues(["default", "mailers"]) end)

      assert output =~ Printer.title(["Paused", "default"])
      assert output =~ Printer.title(["Paused", "mailers"])
    end

    test "does nothing with an empty list" do
      reject(Oban, :pause_queue, 1)

      assert capture_io(fn -> assert :ok = Queues.pause_queues([]) end) == ""
    end

    test "does not pause an invalid queue name" do
      reject(Oban, :pause_queue, 1)

      output = capture_io(fn -> assert :ok = Queues.pause_queues([nil, 1]) end)

      assert output =~ Printer.title(["Pause", nil, "Queue name is not valid"])
      assert output =~ Printer.title(["Pause", 1, "Queue name is not valid"])
    end
  end

  describe "resume_queues/1" do
    test "resumes a queue by name" do
      expect(Oban, :resume_queue, fn [queue: "default"] -> :ok end)

      output = capture_io(fn -> assert :ok = Queues.resume_queues("default") end)

      assert output == Printer.title(["Resumed", "default"]) <> "\n"
    end

    test "resumes each queue in the list" do
      expect(Oban, :resume_queue, fn [queue: "default"] -> :ok end)
      expect(Oban, :resume_queue, fn [queue: "mailers"] -> :ok end)

      output = capture_io(fn -> assert :ok = Queues.resume_queues(["default", "mailers"]) end)

      assert output =~ Printer.title(["Resumed", "default"])
      assert output =~ Printer.title(["Resumed", "mailers"])
    end

    test "does nothing with an empty list" do
      reject(Oban, :resume_queue, 1)

      assert capture_io(fn -> assert :ok = Queues.resume_queues([]) end) == ""
    end

    test "does not resume an invalid queue name" do
      reject(Oban, :resume_queue, 1)

      output = capture_io(fn -> assert :ok = Queues.resume_queues([nil, 1]) end)

      assert output =~ Printer.title(["Resume", nil, "Queue name is not valid"])
      assert output =~ Printer.title(["Resume", 1, "Queue name is not valid"])
    end
  end
end
