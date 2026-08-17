defmodule ObanDoctor.Check.Config.SmartEngineNotConfiguredTest do
  use ExUnit.Case, async: true

  alias ObanDoctor.Check.Config.SmartEngineNotConfigured

  describe "run/1" do
    test "returns info when Oban Pro is installed but Smart Engine not configured" do
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
      assert issue.severity == :info
      assert issue.check == SmartEngineNotConfigured
      assert issue.message =~ "not using Smart Engine"
      assert issue.message =~ "Oban Pro is installed"
      assert issue.meta.instance == Oban
      assert issue.meta.app == :my_app
      assert issue.meta.current_engine == nil
    end

    test "returns no issues when Smart Engine is configured" do
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

      issues = SmartEngineNotConfigured.run(context)

      assert issues == []
    end

    test "returns info when Basic Engine is explicitly configured" do
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
      assert issue.meta.current_engine == Oban.Engines.Basic
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

      context = %{oban_configs: oban_configs, has_oban_pro: false}

      issues = SmartEngineNotConfigured.run(context)

      assert issues == []
    end

    test "returns no issues when has_oban_pro key is missing (defaults to false)" do
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

      context = %{oban_configs: oban_configs}

      issues = SmartEngineNotConfigured.run(context)

      assert issues == []
    end

    test "checks multiple instances independently" do
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
        }
      ]

      context = %{oban_configs: oban_configs, has_oban_pro: true}

      issues = SmartEngineNotConfigured.run(context)

      # Only SecondaryOban should be flagged
      assert length(issues) == 1
      [issue] = issues
      assert issue.meta.instance == MyApp.SecondaryOban
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

    test "formats default Oban instance correctly in message" do
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
      assert issue.message =~ "Oban instance Oban"
    end

    test "returns empty list when oban_configs is empty" do
      context = %{oban_configs: [], has_oban_pro: true}

      issues = SmartEngineNotConfigured.run(context)

      assert issues == []
    end

    test "returns empty list when oban_configs key is missing" do
      context = %{has_oban_pro: true}

      issues = SmartEngineNotConfigured.run(context)

      assert issues == []
    end
  end

  describe "id/0" do
    test "returns :smart_engine_not_configured" do
      assert SmartEngineNotConfigured.id() == :smart_engine_not_configured
    end
  end

  describe "default_severity/0" do
    test "returns :info" do
      assert SmartEngineNotConfigured.default_severity() == :info
    end
  end

  describe "category/0" do
    test "returns :config" do
      assert SmartEngineNotConfigured.category() == :config
    end
  end

  describe "description/0" do
    test "returns description" do
      assert SmartEngineNotConfigured.description() =~
               "Detects Oban instances not using Smart Engine"
    end
  end
end
