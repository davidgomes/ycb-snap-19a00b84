defmodule ObanDoctor.Check.Config.SmartEngineNotConfiguredTest do
  use ExUnit.Case, async: true

  alias ObanDoctor.Check.Config.SmartEngineNotConfigured

  describe "run/1" do
    test "returns info when Oban Pro is installed without Smart Engine" do
      context = %{
        has_oban_pro: true,
        oban_configs: [oban_config(engine: nil)]
      }

      assert [issue] = SmartEngineNotConfigured.run(context)
      assert issue.severity == :info
      assert issue.check == SmartEngineNotConfigured
      assert issue.message =~ "not using Smart Engine"
      assert issue.meta.current_engine == nil
    end

    test "returns no issues when Smart Engine is configured" do
      context = %{
        has_oban_pro: true,
        oban_configs: [oban_config(engine: Oban.Pro.Engines.Smart)]
      }

      assert SmartEngineNotConfigured.run(context) == []
    end

    test "reports an explicitly configured Basic Engine" do
      context = %{
        has_oban_pro: true,
        oban_configs: [oban_config(engine: Oban.Engines.Basic)]
      }

      assert [issue] = SmartEngineNotConfigured.run(context)
      assert issue.meta.current_engine == Oban.Engines.Basic
    end

    test "returns no issues when Oban Pro is not installed" do
      context = %{
        has_oban_pro: false,
        oban_configs: [oban_config(engine: nil)]
      }

      assert SmartEngineNotConfigured.run(context) == []
      assert SmartEngineNotConfigured.run(%{oban_configs: context.oban_configs}) == []
    end

    test "checks multiple instances independently" do
      context = %{
        has_oban_pro: true,
        oban_configs: [
          oban_config(engine: Oban.Pro.Engines.Smart),
          oban_config(name: MyApp.SecondaryOban, engine: nil)
        ]
      }

      assert [issue] = SmartEngineNotConfigured.run(context)
      assert issue.meta.instance == MyApp.SecondaryOban
    end
  end

  test "exposes check metadata" do
    assert SmartEngineNotConfigured.id() == :smart_engine_not_configured
    assert SmartEngineNotConfigured.default_severity() == :info
    assert SmartEngineNotConfigured.category() == :config
  end

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
end
