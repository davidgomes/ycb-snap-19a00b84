defmodule ObanDoctor.Check.Worker.UniquenessMissingStatesTest do
  use ExUnit.Case, async: true

  alias ObanDoctor.Check.Worker.UniquenessMissingStates

  describe "run/1" do
    test "returns warning when worker is missing recommended states" do
      workers = [
        %{
          module: MyApp.Workers.PartialWorker,
          file: "lib/my_app/workers/partial_worker.ex",
          line: 1,
          queue: :default,
          unique: [fields: [:args], states: [:executing]],
          max_attempts: nil
        }
      ]

      context = %{workers: workers}

      issues = UniquenessMissingStates.run(context)

      assert length(issues) == 1
      [issue] = issues
      assert issue.severity == :warning
      assert issue.check == UniquenessMissingStates
      assert issue.message =~ "missing states"
      assert :available in issue.meta.missing_states
      assert :scheduled in issue.meta.missing_states
      assert :retryable in issue.meta.missing_states
    end

    test "returns no issues when worker has all recommended states" do
      workers = [
        %{
          module: MyApp.Workers.CompleteWorker,
          file: "lib/my_app/workers/complete_worker.ex",
          line: 1,
          queue: :default,
          unique: [
            fields: [:args],
            states: [:available, :scheduled, :executing, :retryable]
          ],
          max_attempts: nil
        }
      ]

      context = %{workers: workers}

      issues = UniquenessMissingStates.run(context)

      assert issues == []
    end

    test "returns no issues when worker has no states option" do
      workers = [
        %{
          module: MyApp.Workers.DefaultStatesWorker,
          file: "lib/my_app/workers/default_states_worker.ex",
          line: 1,
          queue: :default,
          unique: [fields: [:args]],
          max_attempts: nil
        }
      ]

      context = %{workers: workers}

      issues = UniquenessMissingStates.run(context)

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

      issues = UniquenessMissingStates.run(context)

      assert issues == []
    end

    test "does not flag workers using :all state group (handled by another check)" do
      workers = [
        %{
          module: MyApp.Workers.AllStatesWorker,
          file: "lib/my_app/workers/all_states_worker.ex",
          line: 1,
          queue: :default,
          unique: [fields: [:args], states: :all],
          max_attempts: nil
        }
      ]

      context = %{workers: workers}

      issues = UniquenessMissingStates.run(context)

      assert issues == []
    end

    test "does not flag workers using :incomplete named group" do
      workers = [
        %{
          module: MyApp.Workers.IncompleteWorker,
          file: "lib/my_app/workers/incomplete_worker.ex",
          line: 1,
          queue: :default,
          unique: [fields: [:args], states: :incomplete],
          max_attempts: nil
        }
      ]

      context = %{workers: workers}

      issues = UniquenessMissingStates.run(context)

      assert issues == []
    end

    test "does not flag workers using :successful named group" do
      workers = [
        %{
          module: MyApp.Workers.SuccessfulWorker,
          file: "lib/my_app/workers/successful_worker.ex",
          line: 1,
          queue: :default,
          unique: [fields: [:args], states: :successful],
          max_attempts: nil
        }
      ]

      context = %{workers: workers}

      issues = UniquenessMissingStates.run(context)

      assert issues == []
    end

    test "does not flag workers using :scheduled named group" do
      workers = [
        %{
          module: MyApp.Workers.ScheduledWorker,
          file: "lib/my_app/workers/scheduled_worker.ex",
          line: 1,
          queue: :default,
          unique: [fields: [:args], states: :scheduled],
          max_attempts: nil
        }
      ]

      context = %{workers: workers}

      issues = UniquenessMissingStates.run(context)

      assert issues == []
    end

    test "does not flag workers using a single-element named group list" do
      workers = [
        %{
          module: MyApp.Workers.IncompleteListWorker,
          file: "lib/my_app/workers/incomplete_list_worker.ex",
          line: 1,
          queue: :default,
          unique: [fields: [:args], states: [:incomplete]],
          max_attempts: nil
        }
      ]

      context = %{workers: workers}

      issues = UniquenessMissingStates.run(context)

      assert issues == []
    end

    test "detects workers missing only some states" do
      workers = [
        %{
          module: MyApp.Workers.AlmostCompleteWorker,
          file: "lib/my_app/workers/almost_complete_worker.ex",
          line: 1,
          queue: :default,
          unique: [fields: [:args], states: [:available, :scheduled, :executing]],
          max_attempts: nil
        }
      ]

      context = %{workers: workers}

      issues = UniquenessMissingStates.run(context)

      assert length(issues) == 1
      [issue] = issues
      assert issue.meta.missing_states == [:retryable]
    end
  end

  describe "id/0" do
    test "returns :uniqueness_missing_states" do
      assert UniquenessMissingStates.id() == :uniqueness_missing_states
    end
  end

  describe "default_severity/0" do
    test "returns :warning" do
      assert UniquenessMissingStates.default_severity() == :warning
    end
  end
end
