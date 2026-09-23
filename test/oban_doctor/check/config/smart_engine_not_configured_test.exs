defmodule ObanDoctor.Check.Config.SmartEngineNotConfiguredTest do
  use ExUnit.Case, async: true

  alias ObanDoctor.Check.Config.SmartEngineNotConfigured

  defp oban_config(overrides \\ []) do
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
    test "returns info when Oban Pro is installed and no engine is configured" do
      context = %{oban_configs: [oban_config()], has_oban_pro: true}

      issues = SmartEngineNotConfigured.run(context)

      assert length(issues) == 1
      [issue] = issues
      assert issue.severity == :info
      assert issue.check == SmartEngineNotConfigured
      assert issue.message =~ "not using the Smart Engine"
      assert issue.file == "config/config.exs"
      assert issue.line == 10
      assert issue.meta.instance == Oban
      assert issue.meta.app == :my_app
      assert issue.meta.engine == nil
    end

    test "returns info when Oban Pro is installed and the Basic engine is configured" do
      config = oban_config(engine: Oban.Engines.Basic)
      context = %{oban_configs: [config], has_oban_pro: true}

      issues = SmartEngineNotConfigured.run(context)

      assert length(issues) == 1
      [issue] = issues
      assert issue.meta.engine == Oban.Engines.Basic
    end

    test "returns no issues when the Smart Engine is configured" do
      config = oban_config(engine: Oban.Pro.Engines.Smart)
      context = %{oban_configs: [config], has_oban_pro: true}

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

    test "flags each instance individually, even when sharing a repo" do
      oban_configs = [
        oban_config(engine: Oban.Pro.Engines.Smart),
        oban_config(name: MyApp.SecondaryOban, line: 20),
        oban_config(name: MyApp.ThirdOban, engine: Oban.Engines.Basic, line: 30)
      ]

      context = %{oban_configs: oban_configs, has_oban_pro: true}

      issues = SmartEngineNotConfigured.run(context)

      assert length(issues) == 2
      assert Enum.map(issues, & &1.meta.instance) == [MyApp.SecondaryOban, MyApp.ThirdOban]
    end

    test "formats named instance correctly in message" do
      config = oban_config(name: Reporting.Oban, app: :reporting)
      context = %{oban_configs: [config], has_oban_pro: true}

      [issue] = SmartEngineNotConfigured.run(context)

      assert issue.message =~ "Reporting.Oban"
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
