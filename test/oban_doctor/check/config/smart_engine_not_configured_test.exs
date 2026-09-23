defmodule ObanDoctor.Check.Config.SmartEngineNotConfiguredTest do
  use ExUnit.Case, async: true

  alias ObanDoctor.Check.Config.SmartEngineNotConfigured

  describe "run/1" do
    test "returns no issues when the project does not depend on Oban Pro" do
      context = %{
        has_oban_pro: false,
        oban_configs: [oban_config(engine: nil)]
      }

      assert SmartEngineNotConfigured.run(context) == []
    end

    test "returns a warning when Oban Pro is present and no engine is set" do
      context = %{
        has_oban_pro: true,
        oban_configs: [oban_config(engine: nil)]
      }

      issues = SmartEngineNotConfigured.run(context)

      assert length(issues) == 1
      [issue] = issues
      assert issue.severity == :warning
      assert issue.check == SmartEngineNotConfigured
      assert issue.message =~ "Oban.Pro.Engines.Smart"
      assert issue.message =~ "Oban instance Oban"
      assert issue.meta.instance == Oban
      assert issue.meta.app == :my_app
      assert issue.meta.engine == nil
    end

    test "returns a warning when a non-Smart engine is configured" do
      context = %{
        has_oban_pro: true,
        oban_configs: [oban_config(engine: Oban.Engines.Basic)]
      }

      issues = SmartEngineNotConfigured.run(context)

      assert length(issues) == 1
      [issue] = issues
      assert issue.meta.engine == Oban.Engines.Basic
    end

    test "returns no issues when Oban.Pro.Engines.Smart is configured" do
      context = %{
        has_oban_pro: true,
        oban_configs: [oban_config(engine: Oban.Pro.Engines.Smart)]
      }

      assert SmartEngineNotConfigured.run(context) == []
    end

    test "flags each instance independently" do
      context = %{
        has_oban_pro: true,
        oban_configs: [
          oban_config(engine: Oban.Pro.Engines.Smart),
          oban_config(
            name: Reporting.Oban,
            app: :reporting,
            engine: nil,
            line: 20
          )
        ]
      }

      issues = SmartEngineNotConfigured.run(context)

      assert length(issues) == 1
      [issue] = issues
      assert issue.meta.instance == Reporting.Oban
      assert issue.message =~ "Reporting.Oban"
    end

    test "detects Oban Pro from the project root when has_oban_pro is not set" do
      tmp_dir = Path.join(System.tmp_dir!(), "oban_doctor_smart_#{:rand.uniform(100_000)}")
      File.mkdir_p!(tmp_dir)
      File.write!(Path.join(tmp_dir, "mix.exs"), "{:oban_pro, \"~> 1.0\"}")

      context = %{
        project_root: tmp_dir,
        oban_configs: [oban_config(engine: nil)]
      }

      issues = SmartEngineNotConfigured.run(context)

      assert length(issues) == 1

      File.rm_rf!(tmp_dir)
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
