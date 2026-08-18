defmodule ObanDoctor.Check.Worker.MissingQueueTest do
  use ExUnit.Case, async: true

  alias ObanDoctor.Check.Worker.MissingQueue

  describe "run/1" do
    test "returns error when worker uses undefined queue" do
      workers = [
        %{
          module: MyApp.Workers.BadWorker,
          file: "lib/my_app/workers/bad_worker.ex",
          line: 1,
          queue: :undefined_queue,
          unique: nil,
          max_attempts: nil
        }
      ]

      context = %{
        workers: workers,
        defined_queues: MapSet.new([:default, :emails])
      }

      issues = MissingQueue.run(context)

      assert length(issues) == 1
      [issue] = issues
      assert issue.severity == :error
      assert issue.check == MissingQueue
      assert issue.message =~ "undefined queue :undefined_queue"
      assert issue.message =~ "https://hexdocs.pm/oban/Oban.html#module-queues"
      assert issue.meta.worker == MyApp.Workers.BadWorker
      assert issue.meta.queue == :undefined_queue
      assert issue.meta.doc_url == "https://hexdocs.pm/oban/Oban.html#module-queues"
    end

    test "returns no issues when worker uses defined queue" do
      workers = [
        %{
          module: MyApp.Workers.GoodWorker,
          file: "lib/my_app/workers/good_worker.ex",
          line: 1,
          queue: :default,
          unique: nil,
          max_attempts: nil
        }
      ]

      context = %{
        workers: workers,
        defined_queues: MapSet.new([:default, :emails])
      }

      issues = MissingQueue.run(context)

      assert issues == []
    end

    test "returns no issues when worker has no queue specified" do
      workers = [
        %{
          module: MyApp.Workers.DefaultWorker,
          file: "lib/my_app/workers/default_worker.ex",
          line: 1,
          queue: nil,
          unique: nil,
          max_attempts: nil
        }
      ]

      context = %{
        workers: workers,
        defined_queues: MapSet.new([:default])
      }

      issues = MissingQueue.run(context)

      assert issues == []
    end

    test "detects multiple workers with undefined queues" do
      workers = [
        %{
          module: MyApp.Workers.Worker1,
          file: "w1.ex",
          line: 1,
          queue: :bad1,
          unique: nil,
          max_attempts: nil
        },
        %{
          module: MyApp.Workers.Worker2,
          file: "w2.ex",
          line: 1,
          queue: :default,
          unique: nil,
          max_attempts: nil
        },
        %{
          module: MyApp.Workers.Worker3,
          file: "w3.ex",
          line: 1,
          queue: :bad2,
          unique: nil,
          max_attempts: nil
        }
      ]

      context = %{
        workers: workers,
        defined_queues: MapSet.new([:default])
      }

      issues = MissingQueue.run(context)

      assert length(issues) == 2
      queues = Enum.map(issues, & &1.meta.queue)
      assert :bad1 in queues
      assert :bad2 in queues
    end
  end

  describe "id/0" do
    test "returns :missing_queue" do
      assert MissingQueue.id() == :missing_queue
    end
  end

  describe "default_severity/0" do
    test "returns :error" do
      assert MissingQueue.default_severity() == :error
    end
  end
end
