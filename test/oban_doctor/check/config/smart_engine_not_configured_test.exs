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
      context = %{oban_configs: [base_config()], has_oban_pro: false}

      assert SmartEngineNotConfigured.run(context) == []
    end

    test "returns no issues when has_oban_pro key is missing" do
      context = %{oban_configs: [base_config()]}

      assert SmartEngineNotConfigured.run(context) == []
    end

    test "checks multiple instances independently" do
      oban_configs = [
        %{base_config() | engine: Oban.Pro.Engines.Smart},
        %{
          base_config()
          | name: MyApp.SecondaryOban,
            queues: [:sync],
            line: 20
        }
      ]

      context = %{oban_configs: oban_configs, has_oban_pro: true}

      issues = SmartEngineNotConfigured.run(context)

      assert length(issues) == 1
      [issue] = issues
      assert issue.meta.instance == MyApp.SecondaryOban
    end

    test "formats named instance correctly in message" do
      oban_configs = [%{base_config() | name: Reporting.Oban, app: :reporting}]

      context = %{oban_configs: oban_configs, has_oban_pro: true}

      [issue] = SmartEngineNotConfigured.run(context)
      assert issue.message =~ "Reporting.Oban"
    end

    test "formats default Oban instance correctly in message" do
      context = %{oban_configs: [base_config()], has_oban_pro: true}

      [issue] = SmartEngineNotConfigured.run(context)
      assert issue.message =~ "Oban instance Oban"
    end

    test "returns empty list when oban_configs is empty" do
      assert SmartEngineNotConfigured.run(%{oban_configs: [], has_oban_pro: true}) == []
    end

    test "returns empty list when oban_configs key is missing" do
      assert SmartEngineNotConfigured.run(%{has_oban_pro: true}) == []
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

  defp base_config do
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
  end
end
