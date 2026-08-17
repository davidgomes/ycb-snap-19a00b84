defmodule ObanDoctor.WorkerDiscoveryTest do
  use ExUnit.Case, async: true

  alias ObanDoctor.WorkerDiscovery

  @fixtures_path Path.join(__DIR__, "../fixtures")

  describe "discover/1" do
    test "finds Oban.Worker modules" do
      workers = WorkerDiscovery.discover(Path.join(@fixtures_path, "sample_project"))

      assert length(workers) >= 1
      modules = Enum.map(workers, & &1.module)
      assert SampleProject.Workers.EmailWorker in modules
    end

    test "extracts queue option" do
      workers = WorkerDiscovery.discover(Path.join(@fixtures_path, "sample_project"))

      email_worker = Enum.find(workers, &(&1.module == SampleProject.Workers.EmailWorker))
      assert email_worker.queue == :emails
    end

    test "extracts max_attempts option" do
      workers = WorkerDiscovery.discover(Path.join(@fixtures_path, "sample_project"))

      email_worker = Enum.find(workers, &(&1.module == SampleProject.Workers.EmailWorker))
      assert email_worker.max_attempts == 5
    end

    test "extracts unique option" do
      workers = WorkerDiscovery.discover(Path.join(@fixtures_path, "sample_project"))

      unique_worker = Enum.find(workers, &(&1.module == SampleProject.Workers.UniqueWorker))
      assert unique_worker.unique[:fields] == [:args, :worker]
      assert unique_worker.unique[:keys] == [:user_id]
      assert unique_worker.unique[:states] == [:available, :scheduled, :executing, :retryable]
    end

    test "ignores non-Oban modules" do
      workers = WorkerDiscovery.discover(Path.join(@fixtures_path, "sample_project"))

      modules = Enum.map(workers, & &1.module)
      refute SampleProject.NotAWorker in modules
    end

    test "returns empty list for directory with no workers" do
      workers = WorkerDiscovery.discover(Path.join(@fixtures_path, "empty_project"))
      assert workers == []
    end

    test "includes file path and line number" do
      workers = WorkerDiscovery.discover(Path.join(@fixtures_path, "sample_project"))

      email_worker = Enum.find(workers, &(&1.module == SampleProject.Workers.EmailWorker))
      assert email_worker.file =~ "email_worker.ex"
      assert email_worker.line == 1
    end
  end
end
