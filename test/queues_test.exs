defmodule Oban.Console.QueuesTest do
  use ExUnit.Case, async: true
  use Mimic

  import ExUnit.CaptureIO

  alias Oban.Console.Queues

  describe "list/0" do
    test "returns paused and local_limit for each configured queue" do
      stub(Oban, :config, fn -> %{queues: [default: 10, mailers: 5]} end)

      stub(Oban, :check_queue, fn
        [queue: :default] ->
          %{queue: :default, paused: false, local_limit: 10, global_limit: nil}

        [queue: :mailers] ->
          %{queue: :mailers, paused: true, local_limit: 5, global_limit: 1}
      end)

      assert Queues.list() == [
               %{queue: :default, paused: false, local_limit: 10},
               %{queue: :mailers, paused: true, local_limit: 5}
             ]
    end
  end

  describe "show_list/0" do
    test "prints a table of queues" do
      stub(Oban, :config, fn -> %{queues: [default: 10]} end)

      stub(Oban, :check_queue, fn [queue: :default] ->
        %{queue: :default, paused: false, local_limit: 10}
      end)

      output = capture_io(fn -> Queues.show_list() end)

      assert output =~ "queue"
      assert output =~ "paused"
      assert output =~ "local_limit"
      assert output =~ ":default"
      assert output =~ "false"
      assert output =~ "10"
    end

    test "prints an empty message when there are no queues" do
      stub(Oban, :config, fn -> %{queues: []} end)

      output = capture_io(fn -> Queues.show_list() end)

      assert output =~ "No records found"
    end
  end

  describe "pause_queues/1" do
    test "pauses a queue by name" do
      expect(Oban, :pause_queue, fn [queue: "default"] -> :ok end)

      output = capture_io(fn -> assert :ok = Queues.pause_queues("default") end)

      assert output =~ "Paused"
      assert output =~ "default"
    end

    test "pauses each queue in a list" do
      expect(Oban, :pause_queue, 2, fn
        [queue: "default"] -> :ok
        [queue: "mailers"] -> :ok
      end)

      output = capture_io(fn -> assert :ok = Queues.pause_queues(["default", "mailers"]) end)

      assert output =~ "Paused"
      assert output =~ "default"
      assert output =~ "mailers"
    end

    test "does nothing for an empty list" do
      reject(Oban, :pause_queue, 1)

      assert :ok = Queues.pause_queues([])
    end

    test "reports an invalid queue name" do
      reject(Oban, :pause_queue, 1)

      output = capture_io(fn -> assert :ok = Queues.pause_queues(:default) end)

      assert output =~ "Pause"
      assert output =~ ":default"
      assert output =~ "Queue name is not valid"
    end
  end

  describe "resume_queues/1" do
    test "resumes a queue by name" do
      expect(Oban, :resume_queue, fn [queue: "default"] -> :ok end)

      output = capture_io(fn -> assert :ok = Queues.resume_queues("default") end)

      assert output =~ "Resumed"
      assert output =~ "default"
    end

    test "resumes each queue in a list" do
      expect(Oban, :resume_queue, 2, fn
        [queue: "default"] -> :ok
        [queue: "mailers"] -> :ok
      end)

      output = capture_io(fn -> assert :ok = Queues.resume_queues(["default", "mailers"]) end)

      assert output =~ "Resumed"
      assert output =~ "default"
      assert output =~ "mailers"
    end

    test "does nothing for an empty list" do
      reject(Oban, :resume_queue, 1)

      assert :ok = Queues.resume_queues([])
    end

    test "reports an invalid queue name" do
      reject(Oban, :resume_queue, 1)

      output = capture_io(fn -> assert :ok = Queues.resume_queues(1) end)

      assert output =~ "Resume"
      assert output =~ "1"
      assert output =~ "Queue name is not valid"
    end
  end
end
