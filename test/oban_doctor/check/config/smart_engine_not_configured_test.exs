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
    test "returns warning when Oban Pro is installed and no engine is set" do
      context = %{oban_configs: [oban_config(engine: nil)], has_oban_pro: true}

      issues = SmartEngineNotConfigured.run(context)

      assert length(issues) == 1
      [issue] = issues
      assert issue.severity == :warning
      assert issue.check == SmartEngineNotConfigured
      assert issue.message =~ "Oban.Pro.Engines.Smart"
      assert issue.meta.instance == Oban
      assert issue.meta.app == :my_app
      assert issue.meta.engine == nil
    end

    test "returns warning when Oban Pro is installed and the Basic engine is set" do
      context = %{
        oban_configs: [oban_config(engine: Oban.Engines.Basic)],
        has_oban_pro: true
      }

      issues = SmartEngineNotConfigured.run(context)

      assert [issue] = issues
      assert issue.meta.engine == Oban.Engines.Basic
    end

    test "returns no issues when Oban.Pro.Engines.Smart is configured" do
      context = %{
        oban_configs: [oban_config(engine: Oban.Pro.Engines.Smart)],
        has_oban_pro: true
      }

      assert SmartEngineNotConfigured.run(context) == []
    end

    test "returns no issues when legacy Oban.Pro.Queue.SmartEngine is configured" do
      context = %{
        oban_configs: [oban_config(engine: Oban.Pro.Queue.SmartEngine)],
        has_oban_pro: true
      }

      assert SmartEngineNotConfigured.run(context) == []
    end

    test "returns no issues when Oban Pro is not installed" do
      context = %{oban_configs: [oban_config(engine: nil)], has_oban_pro: false}

      assert SmartEngineNotConfigured.run(context) == []
    end

    test "returns no issues when has_oban_pro is missing from context" do
      context = %{oban_configs: [oban_config(engine: nil)]}

      assert SmartEngineNotConfigured.run(context) == []
    end

    test "flags each instance without the Smart engine" do
      oban_configs = [
        oban_config(name: Oban, engine: Oban.Pro.Engines.Smart),
        oban_config(name: Reporting.Oban, app: :reporting, engine: nil, line: 20),
        oban_config(name: Mailer.Oban, app: :mailer, engine: Oban.Engines.Basic, line: 30)
      ]

      issues = SmartEngineNotConfigured.run(%{oban_configs: oban_configs, has_oban_pro: true})

      assert length(issues) == 2
      instances = Enum.map(issues, & &1.meta.instance)
      assert Reporting.Oban in instances
      assert Mailer.Oban in instances
      refute Oban in instances
    end

    test "formats named instance correctly in message" do
      context = %{
        oban_configs: [oban_config(name: Reporting.Oban, app: :reporting)],
        has_oban_pro: true
      }

      assert [issue] = SmartEngineNotConfigured.run(context)
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
