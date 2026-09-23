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
        line: 1
      },
      Map.new(attrs)
    )
  end

  test "returns no issues when Oban Pro is not installed" do
    context = %{oban_configs: [config([])], has_oban_pro: false}
    assert SmartEngineNotConfigured.run(context) == []
  end

  test "flags instances without an engine when Oban Pro is installed" do
    context = %{oban_configs: [config([])], has_oban_pro: true}

    assert [issue] = SmartEngineNotConfigured.run(context)
    assert issue.check == SmartEngineNotConfigured
    assert issue.severity == :warning
    assert issue.message =~ "Oban.Pro.Engines.Smart"
    assert issue.meta.instance == Oban
  end

  test "flags instances using a non-Smart engine" do
    context = %{
      oban_configs: [config(engine: Oban.Engines.Basic)],
      has_oban_pro: true
    }

    assert [issue] = SmartEngineNotConfigured.run(context)
    assert issue.meta.engine == Oban.Engines.Basic
  end

  test "passes instances using the Smart engine" do
    context = %{
      oban_configs: [
        config(engine: Oban.Pro.Engines.Smart),
        config(name: MyApp.Other, engine: nil)
      ],
      has_oban_pro: true
    }

    assert [issue] = SmartEngineNotConfigured.run(context)
    assert issue.meta.instance == MyApp.Other
  end

  test "metadata" do
    assert SmartEngineNotConfigured.id() == :smart_engine_not_configured
    assert SmartEngineNotConfigured.default_severity() == :warning
    assert SmartEngineNotConfigured.category() == :config
  end
end
