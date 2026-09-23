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

    test "returns warning when Oban Pro is installed and a non-Smart engine is configured" do
      config = oban_config(engine: Oban.Engines.Basic)
      context = %{oban_configs: [config], has_oban_pro: true}

      assert [issue] = SmartEngineNotConfigured.run(context)
      assert issue.meta.engine == Oban.Engines.Basic
    end

    test "returns no issues when Smart engine is configured" do
      config = oban_config(engine: Oban.Pro.Engines.Smart)
      context = %{oban_configs: [config], has_oban_pro: true}

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
      configs = [
        oban_config(engine: Oban.Pro.Engines.Smart),
        oban_config(name: MyApp.SecondaryOban),
        oban_config(name: MyApp.ThirdOban, engine: Oban.Engines.Basic)
      ]

      context = %{oban_configs: configs, has_oban_pro: true}

      issues = SmartEngineNotConfigured.run(context)

      assert length(issues) == 2
      instances = Enum.map(issues, & &1.meta.instance)
      assert MyApp.SecondaryOban in instances
      assert MyApp.ThirdOban in instances
    end

    test "formats named instances in message" do
      config = oban_config(name: MyApp.SecondaryOban)
      context = %{oban_configs: [config], has_oban_pro: true}

      assert [issue] = SmartEngineNotConfigured.run(context)
      assert issue.message =~ "MyApp.SecondaryOban"
    end

    test "returns empty list when no configs" do
      assert SmartEngineNotConfigured.run(%{oban_configs: [], has_oban_pro: true}) == []
    end
  end

  describe "metadata" do
    test "id/0 returns :smart_engine_not_configured" do
      assert SmartEngineNotConfigured.id() == :smart_engine_not_configured
    end

    test "default_severity/0 returns :warning" do
      assert SmartEngineNotConfigured.default_severity() == :warning
    end

    test "category/0 returns :config" do
      assert SmartEngineNotConfigured.category() == :config
    end
  end
end
