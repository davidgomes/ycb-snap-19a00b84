defmodule ObanDoctor.Check.Config.SmartEngineNotConfiguredTest do
  use ExUnit.Case, async: true

  alias ObanDoctor.Check.Config.SmartEngineNotConfigured

  defp config(attrs) do
    Map.merge(
      %{
        name: Oban,
        app: :my_app,
        repo: MyApp.Repo,
        queues: [:default],
        plugins: [],
        insert_trigger: nil,
        engine: nil,
        file: "config/config.exs",
        line: 10
      },
      Map.new(attrs)
    )
  end

  describe "run/1" do
    test "returns warning when Pro is used and engine is not set" do
      issues = SmartEngineNotConfigured.run(%{has_oban_pro: true, oban_configs: [config([])]})

      assert [issue] = issues
      assert issue.severity == :warning
      assert issue.check == SmartEngineNotConfigured
      assert issue.message =~ "Oban.Pro.Engines.Smart"
      assert issue.meta.instance == Oban
    end

    test "returns warning when Pro is used with a different engine" do
      configs = [config(engine: Oban.Engines.Basic, name: Reporting.Oban)]
      assert [issue] = SmartEngineNotConfigured.run(%{has_oban_pro: true, oban_configs: configs})
      assert issue.message =~ "Reporting.Oban"
      assert issue.meta.engine == Oban.Engines.Basic
    end

    test "returns no issues when Smart engine is configured" do
      configs = [config(engine: Oban.Pro.Engines.Smart)]
      assert SmartEngineNotConfigured.run(%{has_oban_pro: true, oban_configs: configs}) == []
    end

    test "returns no issues when project does not use Oban Pro" do
      assert SmartEngineNotConfigured.run(%{has_oban_pro: false, oban_configs: [config([])]}) == []
      assert SmartEngineNotConfigured.run(%{oban_configs: [config([])]}) == []
    end
  end

  test "metadata" do
    assert SmartEngineNotConfigured.id() == :smart_engine_not_configured
    assert SmartEngineNotConfigured.default_severity() == :warning
    assert SmartEngineNotConfigured.category() == :config
  end
end
