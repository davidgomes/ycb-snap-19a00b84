defmodule ObanDoctor.Check.Worker.NoMaxAttemptsTest do
  use ExUnit.Case, async: true

  alias ObanDoctor.Check.Worker.NoMaxAttempts

  describe "run/1" do
    test "returns info when worker has no max_attempts" do
      workers = [
        %{
          module: MyApp.Workers.DefaultAttemptsWorker,
          file: "lib/my_app/workers/default_attempts_worker.ex",
          line: 1,
          queue: :default,
          unique: nil,
          max_attempts: nil
        }
      ]

      context = %{workers: workers}

      issues = NoMaxAttempts.run(context)

      assert length(issues) == 1
      [issue] = issues
      assert issue.severity == :info
      assert issue.check == NoMaxAttempts
      assert issue.message =~ "default max_attempts (20)"
    end

    test "returns no issues when worker has explicit max_attempts" do
      workers = [
        %{
          module: MyApp.Workers.ExplicitAttemptsWorker,
          file: "lib/my_app/workers/explicit_attempts_worker.ex",
          line: 1,
          queue: :default,
          unique: nil,
          max_attempts: 3
        }
      ]

      context = %{workers: workers}

      issues = NoMaxAttempts.run(context)

      assert issues == []
    end

    test "returns no issues when worker has max_attempts set to 1" do
      workers = [
        %{
          module: MyApp.Workers.OneAttemptWorker,
          file: "lib/my_app/workers/one_attempt_worker.ex",
          line: 1,
          queue: :default,
          unique: nil,
          max_attempts: 1
        }
      ]

      context = %{workers: workers}

      issues = NoMaxAttempts.run(context)

      assert issues == []
    end

    test "detects multiple workers without max_attempts" do
      workers = [
        %{
          module: MyApp.Workers.Worker1,
          file: "w1.ex",
          line: 1,
          queue: :default,
          unique: nil,
          max_attempts: nil
        },
        %{
          module: MyApp.Workers.Worker2,
          file: "w2.ex",
          line: 1,
          queue: :default,
          unique: nil,
          max_attempts: 5
        },
        %{
          module: MyApp.Workers.Worker3,
          file: "w3.ex",
          line: 1,
          queue: :default,
          unique: nil,
          max_attempts: nil
        }
      ]

      context = %{workers: workers}

      issues = NoMaxAttempts.run(context)

      assert length(issues) == 2
      modules = Enum.map(issues, & &1.meta.worker)
      assert MyApp.Workers.Worker1 in modules
      assert MyApp.Workers.Worker3 in modules
    end
  end

  describe "id/0" do
    test "returns :no_max_attempts" do
      assert NoMaxAttempts.id() == :no_max_attempts
    end
  end

  describe "default_severity/0" do
    test "returns :info" do
      assert NoMaxAttempts.default_severity() == :info
    end
  end
end
