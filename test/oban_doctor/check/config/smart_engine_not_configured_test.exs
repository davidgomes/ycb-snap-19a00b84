defmodule ObanDoctor.Check.Config.SmartEngineNotConfiguredTest do
  use ExUnit.Case, async: true

  alias ObanDoctor.Check.Config.SmartEngineNotConfigured

  describe "run/1" do
    test "returns warning when Oban Pro is present and engine is unset" do
      context = %{
        has_oban_pro: true,
        oban_configs: [config(engine: nil)]
      }

      issues = SmartEngineNotConfigured.run(context)

      assert length(issues) == 1
      [issue] = issues
      assert issue.severity == :warning
      assert issue.check == SmartEngineNotConfigured
      assert issue.message =~ "not using Oban.Pro.Engines.Smart"
      assert issue.meta.instance == Oban
      assert issue.meta.app == :my_app
      assert issue.meta.engine == nil
    end

    test "returns warning when a non-Smart engine is configured" do
      context = %{
        has_oban_pro: true,
        oban_configs: [config(engine: Oban.Engines.Basic)]
      }

      issues = SmartEngineNotConfigured.run(context)

      assert length(issues) == 1
      [issue] = issues
      assert issue.meta.engine == Oban.Engines.Basic
    end

    test "returns no issues when Smart engine is configured" do
      context = %{
        has_oban_pro: true,
        oban_configs: [config(engine: Oban.Pro.Engines.Smart)]
      }

      assert SmartEngineNotConfigured.run(context) == []
    end

    test "returns no issues when Oban Pro is not a dependency" do
      context = %{
        has_oban_pro: false,
        oban_configs: [config(engine: nil)]
      }

      assert SmartEngineNotConfigured.run(context) == []
    end

    test "flags each instance that is missing the Smart engine" do
      context = %{
        has_oban_pro: true,
        oban_configs: [
          config(name: Oban, engine: Oban.Pro.Engines.Smart),
          config(name: MyApp.SecondaryOban, engine: nil, line: 20)
        ]
      }

      issues = SmartEngineNotConfigured.run(context)

      assert length(issues) == 1
      [issue] = issues
      assert issue.meta.instance == MyApp.SecondaryOban
      assert issue.message =~ "MyApp.SecondaryOban"
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

  defp config(overrides) do
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
