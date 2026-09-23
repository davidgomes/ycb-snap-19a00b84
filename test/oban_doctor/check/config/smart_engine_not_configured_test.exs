defmodule ObanDoctor.Check.Config.SmartEngineNotConfiguredTest do
  use ExUnit.Case, async: true

  alias ObanDoctor.Check.Config.SmartEngineNotConfigured

  defp oban_config(attrs \\ []) do
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
      Map.new(attrs)
    )
  end

  describe "run/1" do
    test "returns info issue when Oban Pro is installed and no engine is configured" do
      context = %{oban_configs: [oban_config()], has_oban_pro: true}

      issues = SmartEngineNotConfigured.run(context)

      assert [issue] = issues
      assert issue.severity == :info
      assert issue.check == SmartEngineNotConfigured
      assert issue.message =~ "not using the Smart Engine"
      assert issue.file == "config/config.exs"
      assert issue.line == 10
      assert issue.meta.instance == Oban
      assert issue.meta.app == :my_app
      assert issue.meta.engine == nil
    end

    test "returns issue when Oban Pro is installed and a non-Smart engine is configured" do
      context = %{
        oban_configs: [oban_config(engine: Oban.Engines.Basic)],
        has_oban_pro: true
      }

      assert [issue] = SmartEngineNotConfigured.run(context)
      assert issue.meta.engine == Oban.Engines.Basic
    end

    test "returns no issues when the Smart Engine is configured" do
      context = %{
        oban_configs: [oban_config(engine: Oban.Pro.Engines.Smart)],
        has_oban_pro: true
      }

      assert SmartEngineNotConfigured.run(context) == []
    end

    test "returns no issues when Oban Pro is not installed" do
      context = %{oban_configs: [oban_config()], has_oban_pro: false}

      assert SmartEngineNotConfigured.run(context) == []
    end

    test "returns no issues when has_oban_pro is missing from context" do
      context = %{oban_configs: [oban_config()]}

      assert SmartEngineNotConfigured.run(context) == []
    end

    test "flags each instance not using the Smart Engine, even on a shared repo" do
      context = %{
        oban_configs: [
          oban_config(),
          oban_config(name: MyApp.SecondaryOban, engine: Oban.Pro.Engines.Smart),
          oban_config(name: MyApp.ThirdOban, app: :other_app)
        ],
        has_oban_pro: true
      }

      issues = SmartEngineNotConfigured.run(context)

      assert length(issues) == 2
      instances = Enum.map(issues, & &1.meta.instance)
      assert Oban in instances
      assert MyApp.ThirdOban in instances
    end

    test "formats named instances in the message" do
      context = %{
        oban_configs: [oban_config(name: MyApp.SecondaryOban)],
        has_oban_pro: true
      }

      assert [issue] = SmartEngineNotConfigured.run(context)
      assert issue.message =~ "MyApp.SecondaryOban"
    end

    test "returns no issues when there are no Oban configs" do
      assert SmartEngineNotConfigured.run(%{oban_configs: [], has_oban_pro: true}) == []
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
end
