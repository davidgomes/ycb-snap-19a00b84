defmodule ObanDoctor.Check.Config.SmartEngineNotConfiguredTest do
  use ExUnit.Case, async: true

  alias ObanDoctor.Check.Config.SmartEngineNotConfigured

  describe "run/1" do
    test "returns warning when Oban Pro is installed and no engine is configured" do
      oban_configs = [
        %{
          name: Oban,
          app: :my_app,
          repo: MyApp.Repo,
          queues: [:default],
          plugins: [],
          insert_trigger: false,
          engine: nil,
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
      assert issue.message =~ "default Basic engine"
      assert issue.message =~ "Smart engine"
      assert issue.file == "config/config.exs"
      assert issue.line == 10
      assert issue.meta.instance == Oban
      assert issue.meta.app == :my_app
      assert issue.meta.engine == nil
    end

    test "returns warning when Oban Pro is installed and a non-Smart engine is configured" do
      oban_configs = [
        %{
          name: Oban,
          app: :my_app,
          repo: MyApp.Repo,
          queues: [:default],
          plugins: [],
          insert_trigger: false,
          engine: Oban.Engines.Basic,
          file: "config/config.exs",
          line: 10
        }
      ]

      context = %{oban_configs: oban_configs, has_oban_pro: true}

      issues = SmartEngineNotConfigured.run(context)

      assert length(issues) == 1
      [issue] = issues
      assert issue.message =~ "uses Oban.Engines.Basic"
      assert issue.meta.engine == Oban.Engines.Basic
    end

    test "returns no issues when Oban.Pro.Engines.Smart is configured" do
      oban_configs = [
        %{
          name: Oban,
          app: :my_app,
          repo: MyApp.Repo,
          queues: [:default],
          plugins: [],
          insert_trigger: false,
          engine: Oban.Pro.Engines.Smart,
          file: "config/config.exs",
          line: 10
        }
      ]

      context = %{oban_configs: oban_configs, has_oban_pro: true}

      assert SmartEngineNotConfigured.run(context) == []
    end

    test "returns no issues when Oban.Pro.Engine (Pro v1.8+) is configured" do
      oban_configs = [
        %{
          name: Oban,
          app: :my_app,
          repo: MyApp.Repo,
          queues: [:default],
          plugins: [],
          insert_trigger: false,
          engine: Oban.Pro.Engine,
          file: "config/config.exs",
          line: 10
        }
      ]

      context = %{oban_configs: oban_configs, has_oban_pro: true}

      assert SmartEngineNotConfigured.run(context) == []
    end

    test "returns no issues when legacy Oban.Pro.Queue.SmartEngine is configured" do
      oban_configs = [
        %{
          name: Oban,
          app: :my_app,
          repo: MyApp.Repo,
          queues: [:default],
          plugins: [],
          insert_trigger: false,
          engine: Oban.Pro.Queue.SmartEngine,
          file: "config/config.exs",
          line: 10
        }
      ]

      context = %{oban_configs: oban_configs, has_oban_pro: true}

      assert SmartEngineNotConfigured.run(context) == []
    end

    test "returns no issues when Oban Pro is not installed" do
      oban_configs = [
        %{
          name: Oban,
          app: :my_app,
          repo: MyApp.Repo,
          queues: [:default],
          plugins: [],
          insert_trigger: false,
          engine: nil,
          file: "config/config.exs",
          line: 10
        }
      ]

      assert SmartEngineNotConfigured.run(%{oban_configs: oban_configs, has_oban_pro: false}) ==
               []

      assert SmartEngineNotConfigured.run(%{oban_configs: oban_configs}) == []
    end

    test "flags each instance without the Smart engine, even when sharing a repo" do
      oban_configs = [
        %{
          name: Oban,
          app: :my_app,
          repo: MyApp.Repo,
          queues: [:default],
          plugins: [],
          insert_trigger: false,
          engine: Oban.Pro.Engines.Smart,
          file: "config/config.exs",
          line: 10
        },
        %{
          name: MyApp.SecondaryOban,
          app: :my_app,
          repo: MyApp.Repo,
          queues: [:sync],
          plugins: [],
          insert_trigger: false,
          engine: nil,
          file: "config/config.exs",
          line: 20
        },
        %{
          name: Reporting.Oban,
          app: :reporting,
          repo: Reporting.Repo,
          queues: [:reports],
          plugins: [],
          insert_trigger: false,
          engine: Oban.Engines.Basic,
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

    test "treats configs without an engine key as using the default engine" do
      oban_configs = [
        %{
          name: Oban,
          app: :my_app,
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

    test "formats named instance correctly in message" do
      oban_configs = [
        %{
          name: Reporting.Oban,
          app: :reporting,
          repo: Reporting.Repo,
          queues: [:sync],
          plugins: [],
          insert_trigger: false,
          engine: nil,
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
