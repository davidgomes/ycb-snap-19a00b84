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

    test "discovers Oban.Pro.Worker modules" do
      workers = WorkerDiscovery.discover(Path.join(@fixtures_path, "sample_project"))

      pro_worker = Enum.find(workers, &(&1.module == SampleProject.Workers.ProWorker))
      assert pro_worker != nil
      assert pro_worker.uses_oban_worker == true
      assert pro_worker.is_pro == true
      assert pro_worker.queue == :pro_queue
      assert pro_worker.max_attempts == 10
    end

    test "discovers minimal worker with single-statement body" do
      workers = WorkerDiscovery.discover(Path.join(@fixtures_path, "sample_project"))

      minimal_worker = Enum.find(workers, &(&1.module == SampleProject.Workers.MinimalWorker))
      assert minimal_worker != nil
      assert minimal_worker.uses_oban_worker == true
      assert minimal_worker.queue == nil
    end

    test "handles files that cannot be read" do
      tmp_dir = create_temp_project()
      lib_dir = Path.join(tmp_dir, "lib")
      File.mkdir_p!(lib_dir)

      # Create a file and make it unreadable
      file_path = Path.join(lib_dir, "unreadable.ex")
      File.write!(file_path, "defmodule Test do end")
      File.chmod!(file_path, 0o000)

      # Should not crash, just skip the file
      workers = WorkerDiscovery.discover(tmp_dir)
      assert is_list(workers)

      # Restore permissions for cleanup
      File.chmod!(file_path, 0o644)
    end

    test "handles files with syntax errors" do
      tmp_dir = create_temp_project()
      lib_dir = Path.join(tmp_dir, "lib")
      File.mkdir_p!(lib_dir)

      # Create a file with invalid syntax
      file_path = Path.join(lib_dir, "invalid.ex")
      File.write!(file_path, "defmodule Test do def broken(")

      # Should not crash, just skip the file
      workers = WorkerDiscovery.discover(tmp_dir)
      assert is_list(workers)
    end

    test "handles use Oban.Worker with no options" do
      tmp_dir = create_temp_project()
      lib_dir = Path.join(tmp_dir, "lib")
      File.mkdir_p!(lib_dir)

      # Worker with no options at all
      file_path = Path.join(lib_dir, "no_opts_worker.ex")

      File.write!(file_path, """
      defmodule NoOptsWorker do
        use Oban.Worker

        def perform(_job), do: :ok
      end
      """)

      workers = WorkerDiscovery.discover(tmp_dir)
      assert length(workers) == 1
      [worker] = workers
      assert worker.module == NoOptsWorker
      assert worker.queue == nil
      assert worker.max_attempts == nil
    end

    test "handles module with non-Oban use statement" do
      tmp_dir = create_temp_project()
      lib_dir = Path.join(tmp_dir, "lib")
      File.mkdir_p!(lib_dir)

      file_path = Path.join(lib_dir, "other_use.ex")

      File.write!(file_path, """
      defmodule OtherUseWorker do
        use GenServer
        use Oban.Worker, queue: :default

        def perform(_job), do: :ok
      end
      """)

      workers = WorkerDiscovery.discover(tmp_dir)
      assert length(workers) == 1
      [worker] = workers
      assert worker.module == OtherUseWorker
      assert worker.queue == :default
    end

    test "handles worker with tuple value in unique option" do
      tmp_dir = create_temp_project()
      lib_dir = Path.join(tmp_dir, "lib")
      File.mkdir_p!(lib_dir)

      file_path = Path.join(lib_dir, "tuple_worker.ex")

      File.write!(file_path, """
      defmodule TupleWorker do
        use Oban.Worker,
          queue: :default,
          unique: [period: {1, :hour}]
      end
      """)

      workers = WorkerDiscovery.discover(tmp_dir)
      assert length(workers) == 1
      [worker] = workers
      assert worker.unique[:period] == {1, :hour}
    end

    test "handles worker with 3-element tuple value" do
      tmp_dir = create_temp_project()
      lib_dir = Path.join(tmp_dir, "lib")
      File.mkdir_p!(lib_dir)

      file_path = Path.join(lib_dir, "three_tuple_worker.ex")

      # 3+ element tuples are represented as {:{}, _, elements} in AST
      File.write!(file_path, """
      defmodule ThreeTupleWorker do
        use Oban.Worker,
          queue: :default,
          unique: [custom: {:a, :b, :c}]
      end
      """)

      workers = WorkerDiscovery.discover(tmp_dir)
      assert length(workers) == 1
      [worker] = workers
      assert worker.unique[:custom] == {:a, :b, :c}
    end
  end

  # Helper functions

  defp create_temp_project do
    tmp_dir = Path.join(System.tmp_dir!(), "oban_doctor_wd_test_#{:rand.uniform(100_000)}")
    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    tmp_dir
  end
end
