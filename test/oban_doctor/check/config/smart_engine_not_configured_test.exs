defmodule ObanDoctor.Check.Config.SmartEngineNotConfiguredTest do
  use ExUnit.Case, async: true

  alias ObanDoctor.Check.Config.SmartEngineNotConfigured

  describe "run/1" do
    test "returns warning when Oban Pro is installed and no engine is configured" do
      oban_configs = [oban_config(engine: nil)]

      context = %{oban_configs: oban_configs, has_oban_pro: true}

      issues = SmartEngineNotConfigured.run(context)

      assert length(issues) == 1
      [issue] = issues
      assert issue.severity == :warning
      assert issue.check == SmartEngineNotConfigured
      assert issue.message =~ "Smart engine"
      assert issue.file == "config/config.exs"
      assert issue.line == 10
      assert issue.meta.instance == Oban
      assert issue.meta.app == :my_app
    end

    test "returns warning when Oban Pro is installed and the Basic engine is configured" do
      oban_configs = [oban_config(engine: Oban.Engines.Basic)]

      context = %{oban_configs: oban_configs, has_oban_pro: true}

      issues = SmartEngineNotConfigured.run(context)

      assert length(issues) == 1
    end

    test "returns warning when config has no engine key" do
      oban_configs = [Map.delete(oban_config([]), :engine)]

      context = %{oban_configs: oban_configs, has_oban_pro: true}

      issues = SmartEngineNotConfigured.run(context)

      assert length(issues) == 1
    end

    test "returns no issues when Oban.Pro.Engines.Smart is configured" do
      oban_configs = [oban_config(engine: Oban.Pro.Engines.Smart)]

      context = %{oban_configs: oban_configs, has_oban_pro: true}

      assert SmartEngineNotConfigured.run(context) == []
    end

    test "returns no issues when Oban.Pro.Engine (Pro v1.8+) is configured" do
      oban_configs = [oban_config(engine: Oban.Pro.Engine)]

      context = %{oban_configs: oban_configs, has_oban_pro: true}

      assert SmartEngineNotConfigured.run(context) == []
    end

    test "returns no issues when the legacy Oban.Pro.Queue.SmartEngine is configured" do
      oban_configs = [oban_config(engine: Oban.Pro.Queue.SmartEngine)]

      context = %{oban_configs: oban_configs, has_oban_pro: true}

      assert SmartEngineNotConfigured.run(context) == []
    end

    test "returns no issues for non-Postgres engines" do
      oban_configs = [
        oban_config(engine: Oban.Engines.Lite),
        oban_config(name: Reporting.Oban, app: :reporting, engine: Oban.Engines.Dolphin)
      ]

      context = %{oban_configs: oban_configs, has_oban_pro: true}

      assert SmartEngineNotConfigured.run(context) == []
    end

    test "returns no issues when Oban Pro is not installed" do
      oban_configs = [oban_config(engine: nil)]

      context = %{oban_configs: oban_configs, has_oban_pro: false}

      assert SmartEngineNotConfigured.run(context) == []
    end

    test "returns no issues when has_oban_pro is missing from context" do
      oban_configs = [oban_config(engine: nil)]

      context = %{oban_configs: oban_configs}

      assert SmartEngineNotConfigured.run(context) == []
    end

    test "flags each instance individually, even when sharing a repo" do
      oban_configs = [
        oban_config(engine: Oban.Pro.Engines.Smart),
        oban_config(name: MyApp.SecondaryOban, engine: nil, line: 20),
        oban_config(name: MyApp.ThirdOban, engine: Oban.Engines.Basic, line: 30)
      ]

      context = %{oban_configs: oban_configs, has_oban_pro: true}

      issues = SmartEngineNotConfigured.run(context)

      assert length(issues) == 2
      instances = Enum.map(issues, & &1.meta.instance)
      assert MyApp.SecondaryOban in instances
      assert MyApp.ThirdOban in instances
      refute Oban in instances
    end

    test "formats named instance correctly in message" do
      oban_configs = [oban_config(name: Reporting.Oban, app: :reporting, engine: nil)]

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

  defp oban_config(overrides) do
    Map.merge(
      %{
        name: Oban,
        app: :my_app,
        repo: MyApp.Repo,
        queues: [:default],
        plugins: [Oban.Plugins.Pruner],
        insert_trigger: false,
        engine: nil,
        file: "config/config.exs",
        line: 10
      },
      Map.new(overrides)
    )
  end
end
