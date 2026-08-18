defmodule ObanDoctor.Check.Config.SmartEngineNotConfiguredTest do
  use ExUnit.Case, async: true

  alias ObanDoctor.Check.Config.SmartEngineNotConfigured

  describe "run/1" do
    test "returns warning when oban_pro is present but SmartEngine is not configured" do
      tmp_dir = create_temp_project(has_oban_pro: true)

      oban_configs = [
        %{
          name: Oban,
          app: :my_app,
          repo: MyApp.Repo,
          queues: [:default],
          plugins: [Oban.Plugins.Pruner],
          insert_trigger: false,
          file: "config/config.exs",
          line: 10
        }
      ]

      context = %{
        oban_configs: oban_configs,
        project_root: tmp_dir
      }

      issues = SmartEngineNotConfigured.run(context)

      assert length(issues) == 1
      [issue] = issues
      assert issue.severity == :warning
      assert issue.check == SmartEngineNotConfigured
      assert issue.message =~ "Oban Pro is a dependency but SmartEngine plugin is not configured"
      assert issue.file == "config/config.exs"
      assert issue.line == 10
      assert issue.meta.instance == Oban
      assert issue.meta.app == :my_app
    end

    test "returns no issues when oban_pro is present and SmartEngine is configured" do
      tmp_dir = create_temp_project(has_oban_pro: true)

      oban_configs = [
        %{
          name: Oban,
          app: :my_app,
          repo: MyApp.Repo,
          queues: [:default],
          plugins: [Oban.Pro.Plugins.SmartEngine, Oban.Plugins.Pruner],
          insert_trigger: false,
          file: "config/config.exs",
          line: 10
        }
      ]

      context = %{
        oban_configs: oban_configs,
        project_root: tmp_dir
      }

      issues = SmartEngineNotConfigured.run(context)

      assert issues == []
    end

    test "returns no issues when oban_pro is not a dependency" do
      tmp_dir = create_temp_project(has_oban_pro: false)

      oban_configs = [
        %{
          name: Oban,
          app: :my_app,
          repo: MyApp.Repo,
          queues: [:default],
          plugins: [Oban.Plugins.Pruner],
          insert_trigger: false,
          file: "config/config.exs",
          line: 10
        }
      ]

      context = %{
        oban_configs: oban_configs,
        project_root: tmp_dir
      }

      issues = SmartEngineNotConfigured.run(context)

      assert issues == []
    end

    test "returns no issues when project_root is nil or missing" do
      oban_configs = [
        %{
          name: Oban,
          app: :my_app,
          repo: MyApp.Repo,
          queues: [:default],
          plugins: [Oban.Plugins.Pruner],
          insert_trigger: false,
          file: "config/config.exs",
          line: 10
        }
      ]

      context = %{oban_configs: oban_configs}

      issues = SmartEngineNotConfigured.run(context)

      assert issues == []
    end

    test "returns no issues when oban_configs is empty even if oban_pro is present" do
      tmp_dir = create_temp_project(has_oban_pro: true)

      context = %{
        oban_configs: [],
        project_root: tmp_dir
      }

      issues = SmartEngineNotConfigured.run(context)

      assert issues == []
    end

    test "returns no issues when SmartEngine is configured in any instance among multiple" do
      tmp_dir = create_temp_project(has_oban_pro: true)

      oban_configs = [
        %{
          name: Oban,
          app: :my_app,
          repo: MyApp.Repo,
          queues: [:default],
          plugins: [Oban.Plugins.Pruner],
          insert_trigger: false,
          file: "config/config.exs",
          line: 10
        },
        %{
          name: MyApp.SecondaryOban,
          app: :my_app,
          repo: MyApp.Repo,
          queues: [:sync],
          plugins: [Oban.Pro.Plugins.SmartEngine],
          insert_trigger: false,
          file: "config/config.exs",
          line: 20
        }
      ]

      context = %{
        oban_configs: oban_configs,
        project_root: tmp_dir
      }

      issues = SmartEngineNotConfigured.run(context)

      assert issues == []
    end

    test "returns single issue when multiple instances exist but none have SmartEngine" do
      tmp_dir = create_temp_project(has_oban_pro: true)

      oban_configs = [
        %{
          name: Oban,
          app: :my_app,
          repo: MyApp.Repo,
          queues: [:default],
          plugins: [Oban.Plugins.Pruner],
          insert_trigger: false,
          file: "config/config.exs",
          line: 10
        },
        %{
          name: MyApp.SecondaryOban,
          app: :my_app,
          repo: MyApp.Repo,
          queues: [:sync],
          plugins: [],
          insert_trigger: false,
          file: "config/config.exs",
          line: 20
        }
      ]

      context = %{
        oban_configs: oban_configs,
        project_root: tmp_dir
      }

      issues = SmartEngineNotConfigured.run(context)

      assert length(issues) == 1
      [issue] = issues
      assert issue.meta.instance == Oban
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

  defp create_temp_project(opts) do
    tmp_dir = Path.join(System.tmp_dir!(), "smart_engine_test_#{:rand.uniform(100_000)}")
    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)

    if Keyword.get(opts, :has_oban_pro, false) do
      mix_content = """
      defmodule MyApp.MixProject do
        use Mix.Project

        defp deps do
          [
            {:oban, "~> 2.0"},
            {:oban_pro, "~> 1.0", repo: "oban"}
          ]
        end
      end
      """

      File.write!(Path.join(tmp_dir, "mix.exs"), mix_content)
    else
      mix_content = """
      defmodule MyApp.MixProject do
        use Mix.Project

        defp deps do
          [
            {:oban, "~> 2.0"}
          ]
        end
      end
      """

      File.write!(Path.join(tmp_dir, "mix.exs"), mix_content)
    end

    tmp_dir
  end
end
