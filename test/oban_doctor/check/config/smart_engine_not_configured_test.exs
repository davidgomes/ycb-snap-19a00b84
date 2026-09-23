defmodule ObanDoctor.Check.Config.SmartEngineNotConfiguredTest do
  use ExUnit.Case, async: true

  alias ObanDoctor.Check.Config.SmartEngineNotConfigured

  describe "run/1" do
    test "returns warning when Oban Pro is installed and no engine is set" do
      oban_configs = [
        %{
          name: Oban,
          app: :my_app,
          repo: MyApp.Repo,
          engine: nil,
          queues: [:default],
          plugins: [],
          insert_trigger: false,
          file: "config/config.exs",
          line: 10
        }
      ]

      context = %{oban_configs: oban_configs, has_oban_pro: true}

      issues = SmartEngineNotConfigured.run(context)

      assert length(issues) == 1
      [issue] = issues
      assert issue.severity == :warning
      assert issue.check == SmartEngineNotConfigured
      assert issue.message =~ "not using the Smart engine"
      assert issue.file == "config/config.exs"
      assert issue.line == 10
      assert issue.meta.instance == Oban
      assert issue.meta.app == :my_app
    end

    test "returns warning when Oban Pro is installed and Basic engine is set explicitly" do
      oban_configs = [
        %{
          name: Oban,
          app: :my_app,
          repo: MyApp.Repo,
          engine: Oban.Engines.Basic,
          queues: [:default],
          plugins: [],
          insert_trigger: false,
          file: "config/config.exs",
          line: 10
        }
      ]

      context = %{oban_configs: oban_configs, has_oban_pro: true}

      issues = SmartEngineNotConfigured.run(context)

      assert length(issues) == 1
    end

    test "returns no issues when Smart engine is configured" do
      oban_configs = [
        %{
          name: Oban,
          app: :my_app,
          repo: MyApp.Repo,
          engine: Oban.Pro.Engines.Smart,
          queues: [:default],
          plugins: [],
          insert_trigger: false,
          file: "config/config.exs",
          line: 10
        }
      ]

      context = %{oban_configs: oban_configs, has_oban_pro: true}

      issues = SmartEngineNotConfigured.run(context)

      assert issues == []
    end

    test "returns no issues for engines that don't support Smart" do
      oban_configs = [
        %{
          name: Oban,
          app: :my_app,
          repo: MyApp.Repo,
          engine: Oban.Engines.Lite,
          queues: [:default],
          plugins: [],
          insert_trigger: false,
          file: "config/config.exs",
          line: 10
        },
        %{
          name: Reporting.Oban,
          app: :reporting,
          repo: Reporting.Repo,
          engine: Oban.Engines.Dolphin,
          queues: [:sync],
          plugins: [],
          insert_trigger: false,
          file: "config/config.exs",
          line: 20
        }
      ]

      context = %{oban_configs: oban_configs, has_oban_pro: true}

      issues = SmartEngineNotConfigured.run(context)

      assert issues == []
    end

    test "returns no issues when Oban Pro is not installed" do
      oban_configs = [
        %{
          name: Oban,
          app: :my_app,
          repo: MyApp.Repo,
          engine: nil,
          queues: [:default],
          plugins: [],
          insert_trigger: false,
          file: "config/config.exs",
          line: 10
        }
      ]

      assert SmartEngineNotConfigured.run(%{oban_configs: oban_configs, has_oban_pro: false}) ==
               []

      assert SmartEngineNotConfigured.run(%{oban_configs: oban_configs}) == []
    end

    test "flags each instance individually, even when sharing a repo" do
      oban_configs = [
        %{
          name: Oban,
          app: :my_app,
          repo: MyApp.Repo,
          engine: Oban.Pro.Engines.Smart,
          queues: [:default],
          plugins: [],
          insert_trigger: false,
          file: "config/config.exs",
          line: 10
        },
        %{
          name: MyApp.SecondaryOban,
          app: :my_app,
          repo: MyApp.Repo,
          engine: nil,
          queues: [:sync],
          plugins: [],
          insert_trigger: false,
          file: "config/config.exs",
          line: 20
        },
        %{
          name: Reporting.Oban,
          app: :reporting,
          repo: MyApp.Repo,
          engine: nil,
          queues: [:reports],
          plugins: [],
          insert_trigger: false,
          file: "config/config.exs",
          line: 30
        }
      ]

      context = %{oban_configs: oban_configs, has_oban_pro: true}

      issues = SmartEngineNotConfigured.run(context)

      assert length(issues) == 2
      instances = Enum.map(issues, & &1.meta.instance)
      assert MyApp.SecondaryOban in instances
      assert Reporting.Oban in instances
      refute Oban in instances
    end

    test "formats named instance correctly in message" do
      oban_configs = [
        %{
          name: Reporting.Oban,
          app: :reporting,
          repo: Reporting.Repo,
          engine: nil,
          queues: [:sync],
          plugins: [],
          insert_trigger: false,
          file: "config/config.exs",
          line: 10
        }
      ]

      context = %{oban_configs: oban_configs, has_oban_pro: true}

      issues = SmartEngineNotConfigured.run(context)

      assert length(issues) == 1
      [issue] = issues
      assert issue.message =~ "Reporting.Oban"
    end
  end

  describe "id/0" do
    test "returns :smart_engine_not_configured" do
      assert SmartEngineNotConfigured.id() == :smart_engine_not_configured
    end
  end

  describe "default_severity/0" do
    test "returns :warning" do
      assert SmartEngineNotConfigured.default_severity() == :warning
    end
  end

  describe "category/0" do
    test "returns :config" do
      assert SmartEngineNotConfigured.category() == :config
    end
  end
end
