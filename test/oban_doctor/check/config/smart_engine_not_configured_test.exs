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

  test "flags Pro users without Smart engine" do
    context = %{oban_configs: [config(plugins: [Oban.Pro.Plugins.DynamicPruner])]}

    assert [issue] = SmartEngineNotConfigured.run(context)
    assert issue.check == SmartEngineNotConfigured
    assert issue.severity == :warning
    assert issue.message =~ "Oban.Pro.Engines.Smart"
  end

  test "no issue when Smart engine is configured" do
    context = %{
      oban_configs: [
        config(plugins: [Oban.Pro.Plugins.DynamicPruner], engine: Oban.Pro.Engines.Smart)
      ]
    }

    assert SmartEngineNotConfigured.run(context) == []
  end

  test "no issue when Oban Pro isn't used" do
    context = %{oban_configs: [config(plugins: [Oban.Plugins.Pruner])]}
    assert SmartEngineNotConfigured.run(context) == []
  end

  test "detects Oban Pro from mix.exs" do
    root = Path.join(System.tmp_dir!(), "smart_engine_#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    File.write!(Path.join(root, "mix.exs"), "defp deps, do: [{:oban_pro, \"~> 1.0\"}]")
    on_exit(fn -> File.rm_rf!(root) end)

    context = %{oban_configs: [config([])], project_root: root}
    assert [_] = SmartEngineNotConfigured.run(context)
  end

  test "metadata" do
    assert SmartEngineNotConfigured.id() == :smart_engine_not_configured
    assert SmartEngineNotConfigured.default_severity() == :warning
    assert SmartEngineNotConfigured.category() == :config
  end
end
