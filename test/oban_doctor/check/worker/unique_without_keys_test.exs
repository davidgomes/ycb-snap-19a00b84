defmodule ObanDoctor.Check.Worker.UniqueWithoutKeysTest do
  use ExUnit.Case, async: true

  alias ObanDoctor.Check.Worker.UniqueWithoutKeys

  describe "run/1" do
    test "returns info when worker has unique on :args without keys" do
      workers = [
        %{
          module: MyApp.Workers.NoKeysWorker,
          file: "lib/my_app/workers/no_keys_worker.ex",
          line: 1,
          queue: :default,
          unique: [fields: [:args]],
          max_attempts: nil
        }
      ]

      context = %{workers: workers}

      issues = UniqueWithoutKeys.run(context)

      assert length(issues) == 1
      [issue] = issues
      assert issue.severity == :info
      assert issue.check == UniqueWithoutKeys
      assert issue.message =~ "without explicit keys"
      assert issue.message =~ "https://hexdocs.pm/oban/Oban.Worker.html#module-unique-jobs"
      assert issue.meta.doc_url == "https://hexdocs.pm/oban/Oban.Worker.html#module-unique-jobs"
    end

    test "returns no issues when worker has unique with keys" do
      workers = [
        %{
          module: MyApp.Workers.WithKeysWorker,
          file: "lib/my_app/workers/with_keys_worker.ex",
          line: 1,
          queue: :default,
          unique: [fields: [:args], keys: [:user_id, :action]],
          max_attempts: nil
        }
      ]

      context = %{workers: workers}

      issues = UniqueWithoutKeys.run(context)

      assert issues == []
    end

    test "returns no issues when worker unique doesn't include :args" do
      workers = [
        %{
          module: MyApp.Workers.WorkerOnlyWorker,
          file: "lib/my_app/workers/worker_only_worker.ex",
          line: 1,
          queue: :default,
          unique: [fields: [:worker]],
          max_attempts: nil
        }
      ]

      context = %{workers: workers}

      issues = UniqueWithoutKeys.run(context)

      assert issues == []
    end

    test "returns no issues when worker has no unique config" do
      workers = [
        %{
          module: MyApp.Workers.SimpleWorker,
          file: "lib/my_app/workers/simple_worker.ex",
          line: 1,
          queue: :default,
          unique: nil,
          max_attempts: nil
        }
      ]

      context = %{workers: workers}

      issues = UniqueWithoutKeys.run(context)

      assert issues == []
    end

    test "detects multiple workers with args but no keys" do
      workers = [
        %{
          module: MyApp.Workers.Worker1,
          file: "w1.ex",
          line: 1,
          queue: :default,
          unique: [fields: [:args]],
          max_attempts: nil
        },
        %{
          module: MyApp.Workers.Worker2,
          file: "w2.ex",
          line: 1,
          queue: :default,
          unique: [fields: [:args], keys: [:id]],
          max_attempts: nil
        },
        %{
          module: MyApp.Workers.Worker3,
          file: "w3.ex",
          line: 1,
          queue: :default,
          unique: [fields: [:args, :worker]],
          max_attempts: nil
        }
      ]

      context = %{workers: workers}

      issues = UniqueWithoutKeys.run(context)

      assert length(issues) == 2
      modules = Enum.map(issues, & &1.meta.worker)
      assert MyApp.Workers.Worker1 in modules
      assert MyApp.Workers.Worker3 in modules
    end
  end

  describe "id/0" do
    test "returns :unique_without_keys" do
      assert UniqueWithoutKeys.id() == :unique_without_keys
    end
  end

  describe "default_severity/0" do
    test "returns :info" do
      assert UniqueWithoutKeys.default_severity() == :info
    end
  end
end
