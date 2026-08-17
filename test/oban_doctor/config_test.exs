defmodule ObanDoctor.ConfigTest do
  use ExUnit.Case, async: true

  alias ObanDoctor.Config

  describe "new/1" do
    test "creates config with defaults" do
      config = Config.new()

      assert config.checks == %{}
      assert config.excluded_workers == []
      assert config.excluded_files == []
    end

    test "creates config with provided attributes" do
      config = Config.new(excluded_workers: [MyApp.Worker])

      assert config.excluded_workers == [MyApp.Worker]
    end
  end

  describe "check_enabled?/2" do
    test "returns true by default" do
      config = Config.new()

      assert Config.check_enabled?(config, :missing_queue) == true
    end

    test "returns false when check is disabled" do
      config = Config.from_keyword(checks: [missing_queue: [enabled: false]])

      assert Config.check_enabled?(config, :missing_queue) == false
    end

    test "returns true when check is explicitly enabled" do
      config = Config.from_keyword(checks: [missing_queue: [enabled: true]])

      assert Config.check_enabled?(config, :missing_queue) == true
    end
  end

  describe "severity_override/2" do
    test "returns nil by default" do
      config = Config.new()

      assert Config.severity_override(config, :missing_queue) == nil
    end

    test "returns configured severity" do
      config = Config.from_keyword(checks: [missing_queue: [severity: :warning]])

      assert Config.severity_override(config, :missing_queue) == :warning
    end
  end

  describe "worker_excluded?/2" do
    test "returns false by default" do
      config = Config.new()

      assert Config.worker_excluded?(config, MyApp.Workers.SomeWorker) == false
    end

    test "returns true for excluded worker" do
      config = Config.from_keyword(excluded_workers: [MyApp.Workers.ExcludedWorker])

      assert Config.worker_excluded?(config, MyApp.Workers.ExcludedWorker) == true
      assert Config.worker_excluded?(config, MyApp.Workers.OtherWorker) == false
    end
  end

  describe "file_excluded?/2" do
    test "returns false by default" do
      config = Config.new()

      assert Config.file_excluded?(config, "lib/my_app/workers/some_worker.ex") == false
    end

    test "returns true for file matching excluded pattern" do
      config = Config.from_keyword(excluded_files: ["test/support/", "workers/legacy/"])

      assert Config.file_excluded?(config, "test/support/factory.ex") == true
      assert Config.file_excluded?(config, "lib/workers/legacy/old_worker.ex") == true
      assert Config.file_excluded?(config, "lib/workers/new_worker.ex") == false
    end
  end

  describe "excluded_workers_for_check/2" do
    test "returns empty list by default" do
      config = Config.new()

      assert Config.excluded_workers_for_check(config, :no_max_attempts) == []
    end

    test "returns workers excluded for specific check" do
      config =
        Config.from_keyword(
          checks: [
            no_max_attempts: [excluded_workers: [MyApp.Workers.LegacyWorker]],
            missing_queue: [excluded_workers: [MyApp.Workers.OtherWorker]]
          ]
        )

      assert Config.excluded_workers_for_check(config, :no_max_attempts) == [
               MyApp.Workers.LegacyWorker
             ]

      assert Config.excluded_workers_for_check(config, :missing_queue) == [
               MyApp.Workers.OtherWorker
             ]

      assert Config.excluded_workers_for_check(config, :state_group_usage) == []
    end
  end

  describe "excluded_instances_for_check/2" do
    test "returns empty list by default" do
      config = Config.new()

      assert Config.excluded_instances_for_check(config, :missing_pruner) == []
    end

    test "returns instances excluded for specific check" do
      config =
        Config.from_keyword(
          checks: [
            missing_pruner: [excluded_instances: [MyApp.SecondaryOban]],
            no_reindexer: [excluded_instances: [MyApp.ThirdOban]]
          ]
        )

      assert Config.excluded_instances_for_check(config, :missing_pruner) == [
               MyApp.SecondaryOban
             ]

      assert Config.excluded_instances_for_check(config, :no_reindexer) == [MyApp.ThirdOban]
      assert Config.excluded_instances_for_check(config, :insert_trigger_enabled) == []
    end
  end

  describe "from_keyword/1" do
    test "parses complete config" do
      keyword = [
        checks: [
          missing_queue: [enabled: false, severity: :warning],
          no_max_attempts: [enabled: true]
        ],
        excluded_workers: [MyApp.LegacyWorker],
        excluded_files: ["test/"]
      ]

      config = Config.from_keyword(keyword)

      assert Config.check_enabled?(config, :missing_queue) == false
      assert Config.severity_override(config, :missing_queue) == :warning
      assert Config.check_enabled?(config, :no_max_attempts) == true
      assert Config.worker_excluded?(config, MyApp.LegacyWorker) == true
      assert Config.file_excluded?(config, "test/support/worker.ex") == true
    end

    test "parses per-check exclusions" do
      keyword = [
        checks: [
          no_max_attempts: [
            excluded_workers: [MyApp.Workers.LegacyWorker]
          ],
          missing_pruner: [
            excluded_instances: [MyApp.SecondaryOban]
          ]
        ]
      ]

      config = Config.from_keyword(keyword)

      assert Config.excluded_workers_for_check(config, :no_max_attempts) == [
               MyApp.Workers.LegacyWorker
             ]

      assert Config.excluded_instances_for_check(config, :missing_pruner) == [
               MyApp.SecondaryOban
             ]
    end

    test "handles empty keyword list" do
      config = Config.from_keyword([])

      assert config.checks == %{}
      assert config.excluded_workers == []
      assert config.excluded_files == []
    end
  end
end
