defmodule ObanDoctor.Check.Config.SmartEngineNotConfiguredTest do
  use ExUnit.Case, async: true

  alias ObanDoctor.Check.Config.SmartEngineNotConfigured

  describe "run/1" do
    test "returns warning when Oban Pro is installed and engine is not set" do
      context = %{
        oban_configs: [oban_config(engine: nil)],
        project_root: project_with_oban_pro()
      }

      issues = SmartEngineNotConfigured.run(context)

      assert length(issues) == 1
      [issue] = issues
      assert issue.severity == :warning
      assert issue.check == SmartEngineNotConfigured
      assert issue.message =~ "does not use Oban.Pro.Engines.Smart"
      assert issue.meta.instance == Oban
      assert issue.meta.app == :my_app
      assert issue.meta.engine == nil
    end

    test "returns warning when Oban Pro is installed and the Basic engine is set" do
      context = %{
        oban_configs: [oban_config(engine: Oban.Engines.Basic)],
        project_root: project_with_oban_pro()
      }

      issues = SmartEngineNotConfigured.run(context)

      assert length(issues) == 1
      [issue] = issues
      assert issue.meta.engine == Oban.Engines.Basic
    end

    test "returns no issues when the Smart engine is configured" do
      context = %{
        oban_configs: [oban_config(engine: Oban.Pro.Engines.Smart)],
        project_root: project_with_oban_pro()
      }

      assert SmartEngineNotConfigured.run(context) == []
    end

    test "returns no issues when Oban Pro is not a dependency" do
      context = %{
        oban_configs: [oban_config(engine: nil)],
        project_root: project_without_oban_pro()
      }

      assert SmartEngineNotConfigured.run(context) == []
    end

    test "returns no issues when project root is missing from the context" do
      context = %{oban_configs: [oban_config(engine: nil)]}

      assert SmartEngineNotConfigured.run(context) == []
    end

    test "flags each instance missing the Smart engine" do
      configs = [
        oban_config(engine: Oban.Pro.Engines.Smart),
        oban_config(name: MyApp.SecondaryOban, engine: nil, line: 20),
        oban_config(name: Reporting.Oban, app: :reporting, engine: nil, line: 30)
      ]

      context = %{oban_configs: configs, project_root: project_with_oban_pro()}

      issues = SmartEngineNotConfigured.run(context)

      assert length(issues) == 2
      assert Enum.map(issues, & &1.meta.instance) == [MyApp.SecondaryOban, Reporting.Oban]
    end

    test "formats named instance in message" do
      context = %{
        oban_configs: [oban_config(name: Reporting.Oban, engine: nil)],
        project_root: project_with_oban_pro()
      }

      issues = SmartEngineNotConfigured.run(context)

      assert [issue] = issues
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

  defp oban_config(overrides) do
    defaults = %{
      name: Oban,
      app: :my_app,
      repo: MyApp.Repo,
      queues: [:default],
      plugins: [],
      engine: nil,
      insert_trigger: false,
      file: "config/config.exs",
      line: 10
    }

    Enum.into(overrides, defaults)
  end

  defp project_with_oban_pro do
    create_temp_project("""
    defmodule MyApp.MixProject do
      use Mix.Project

      defp deps do
        [
          {:oban, "~> 2.0"},
          {:oban_pro, "~> 1.0", repo: "oban"}
        ]
      end
    end
    """)
  end

  defp project_without_oban_pro do
    create_temp_project("""
    defmodule MyApp.MixProject do
      use Mix.Project

      defp deps do
        [
          {:oban, "~> 2.0"}
        ]
      end
    end
    """)
  end

  defp create_temp_project(mix_content) do
    tmp_dir = Path.join(System.tmp_dir!(), "oban_doctor_test_#{:rand.uniform(100_000)}")
    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    File.write!(Path.join(tmp_dir, "mix.exs"), mix_content)
    tmp_dir
  end
end
