defmodule ObanDoctor.Check.Config.SmartEngineNotConfiguredTest do
  use ExUnit.Case, async: true

  alias ObanDoctor.Check.Config.SmartEngineNotConfigured

  defp oban_config(overrides) do
    Map.merge(
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
      },
      Map.new(overrides)
    )
  end

  describe "run/1" do
    test "returns warning when Oban Pro is installed and no engine is configured" do
      context = %{oban_configs: [oban_config([])], has_oban_pro: true}

      issues = SmartEngineNotConfigured.run(context)

      assert [issue] = issues
      assert issue.severity == :warning
      assert issue.check == SmartEngineNotConfigured
      assert issue.message =~ "Oban.Pro.Engines.Smart"
      assert issue.meta.instance == Oban
      assert issue.meta.app == :my_app
      assert issue.meta.engine == nil
    end

    test "returns warning when Oban Pro is installed and a different engine is configured" do
      context = %{
        oban_configs: [oban_config(engine: Oban.Engines.Basic)],
        has_oban_pro: true
      }

      assert [issue] = SmartEngineNotConfigured.run(context)
      assert issue.meta.engine == Oban.Engines.Basic
    end

    test "returns no issues when Smart engine is configured" do
      context = %{
        oban_configs: [oban_config(engine: Oban.Pro.Engines.Smart)],
        has_oban_pro: true
      }

      assert SmartEngineNotConfigured.run(context) == []
    end

    test "returns no issues when Oban Pro is not installed" do
      context = %{oban_configs: [oban_config([])], has_oban_pro: false}

      assert SmartEngineNotConfigured.run(context) == []
    end

    test "returns no issues when has_oban_pro is missing from context" do
      context = %{oban_configs: [oban_config([])]}

      assert SmartEngineNotConfigured.run(context) == []
    end

    test "flags each instance without the Smart engine" do
      context = %{
        oban_configs: [
          oban_config(engine: Oban.Pro.Engines.Smart),
          oban_config(name: Reporting.Oban, app: :reporting, line: 20),
          oban_config(name: MyApp.SecondaryOban, line: 30)
        ],
        has_oban_pro: true
      }

      issues = SmartEngineNotConfigured.run(context)

      assert length(issues) == 2
      assert Enum.map(issues, & &1.meta.instance) == [Reporting.Oban, MyApp.SecondaryOban]
      assert Enum.any?(issues, &(&1.message =~ "Reporting.Oban"))
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
