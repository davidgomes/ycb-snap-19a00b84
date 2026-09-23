defmodule ObanDoctor.Check.Worker.StateGroupUsageTest do
  use ExUnit.Case, async: true

  alias ObanDoctor.Check.Worker.StateGroupUsage

  describe "run/1" do
    test "returns error when worker uses states: :all" do
      workers = [
        %{
          module: MyApp.Workers.BadWorker,
          file: "lib/my_app/workers/bad_worker.ex",
          line: 1,
          queue: :default,
          unique: [fields: [:args], states: :all],
          max_attempts: nil
        }
      ]

      context = %{workers: workers}

      issues = StateGroupUsage.run(context)

      assert length(issues) == 1
      [issue] = issues
      assert issue.severity == :error
      assert issue.check == StateGroupUsage
      assert issue.message =~ ":all state group"
      assert issue.message =~ "cannot be re-enqueued"
      assert issue.message =~ "https://hexdocs.pm/oban/Oban.Job.html#unique_states/1"
      assert issue.meta.state_group == :all
      assert issue.meta.docs =~ "unique_states"
    end

    test "returns error when worker uses states: [:all]" do
      workers = [
        %{
          module: MyApp.Workers.BadWorker,
          file: "lib/my_app/workers/bad_worker.ex",
          line: 1,
          queue: :default,
          unique: [fields: [:args], states: [:all]],
          max_attempts: nil
        }
      ]

      context = %{workers: workers}

      issues = StateGroupUsage.run(context)

      assert length(issues) == 1
    end

    test "returns error when :all is mixed with other states" do
      workers = [
        %{
          module: MyApp.Workers.BadWorker,
          file: "lib/my_app/workers/bad_worker.ex",
          line: 1,
          queue: :default,
          unique: [fields: [:args], states: [:available, :all]],
          max_attempts: nil
        }
      ]

      context = %{workers: workers}

      issues = StateGroupUsage.run(context)

      assert length(issues) == 1
    end

    test "returns no issues for the :incomplete named state group" do
      workers = [
        worker(MyApp.Workers.IncompleteWorker, states: :incomplete)
      ]

      assert StateGroupUsage.run(%{workers: workers}) == []
    end

    test "returns no issues for the :successful named state group" do
      workers = [
        worker(MyApp.Workers.SuccessfulWorker, states: :successful)
      ]

      assert StateGroupUsage.run(%{workers: workers}) == []
    end

    test "returns no issues for the :scheduled named state group" do
      workers = [
        worker(MyApp.Workers.ScheduledWorker, states: :scheduled)
      ]

      assert StateGroupUsage.run(%{workers: workers}) == []
    end

    test "returns no issues when worker uses explicit states" do
      workers = [
        %{
          module: MyApp.Workers.GoodWorker,
          file: "lib/my_app/workers/good_worker.ex",
          line: 1,
          queue: :default,
          unique: [fields: [:args], states: [:available, :scheduled, :executing, :retryable]],
          max_attempts: nil
        }
      ]

      context = %{workers: workers}

      issues = StateGroupUsage.run(context)

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

      issues = StateGroupUsage.run(context)

      assert issues == []
    end
  end

  describe "id/0" do
    test "returns :state_group_usage" do
      assert StateGroupUsage.id() == :state_group_usage
    end
  end

  describe "default_severity/0" do
    test "returns :error" do
      assert StateGroupUsage.default_severity() == :error
    end
  end

  defp worker(module, opts) do
    %{
      module: module,
      file: "lib/my_app/workers/worker.ex",
      line: 1,
      queue: :default,
      unique: [fields: [:args], states: Keyword.fetch!(opts, :states)],
      max_attempts: nil
    }
  end
end
