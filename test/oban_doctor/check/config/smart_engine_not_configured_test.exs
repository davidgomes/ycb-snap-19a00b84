defmodule ObanDoctor.Check.Config.SmartEngineNotConfiguredTest do
  use ExUnit.Case, async: true

  alias ObanDoctor.Check.Config.SmartEngineNotConfigured

  describe "run/1" do
    test "returns warning when Oban Pro is installed and engine is not configured" do
      tmp_dir = create_temp_project_with_pro()

      oban_configs = [
        %{
          name: Oban,
          app: :my_app,
          queues: [:default],
          plugins: [],
          insert_trigger: false,
          engine: nil,
          file: "config/config.exs",
          line: 10
        }
      ]

      context = %{oban_configs: oban_configs, project_root: tmp_dir}

      issues = SmartEngineNotConfigured.run(context)

      assert length(issues) == 1
      [issue] = issues
      assert issue.severity == :warning
      assert issue.check == SmartEngineNotConfigured
      assert issue.message =~ "SmartEngine"
      assert issue.meta.instance == Oban
      assert issue.meta.app == :my_app
      assert issue.meta.engine == nil
    end

    test "returns warning when Oban Pro is installed and basic engine is configured" do
      tmp_dir = create_temp_project_with_pro()

      oban_configs = [
        %{
          name: Oban,
          app: :my_app,
          queues: [:default],
          plugins: [],
          insert_trigger: false,
          engine: Oban.Engines.Basic,
          file: "config/config.exs",
          line: 10
        }
      ]

      context = %{oban_configs: oban_configs, project_root: tmp_dir}

      issues = SmartEngineNotConfigured.run(context)

      assert length(issues) == 1
      [issue] = issues
      assert issue.severity == :warning
      assert issue.meta.engine == Oban.Engines.Basic
    end

    test "returns no issues when Oban Pro is installed and Oban.Pro.Engines.Smart is configured" do
      tmp_dir = create_temp_project_with_pro()

      oban_configs = [
        %{
          name: Oban,
          app: :my_app,
          queues: [:default],
          plugins: [],
          insert_trigger: false,
          engine: Oban.Pro.Engines.Smart,
          file: "config/config.exs",
          line: 10
        }
      ]

      context = %{oban_configs: oban_configs, project_root: tmp_dir}

      issues = SmartEngineNotConfigured.run(context)

      assert issues == []
    end

    test "returns no issues when Oban Pro is installed and Oban.Pro.Queue.SmartEngine is configured" do
      tmp_dir = create_temp_project_with_pro()

      oban_configs = [
        %{
          name: Oban,
          app: :my_app,
          queues: [:default],
          plugins: [],
          insert_trigger: false,
          engine: Oban.Pro.Queue.SmartEngine,
          file: "config/config.exs",
          line: 10
        }
      ]

      context = %{oban_configs: oban_configs, project_root: tmp_dir}

      issues = SmartEngineNotConfigured.run(context)

      assert issues == []
    end

    test "returns no issues when Oban Pro is NOT installed even if engine is nil" do
      tmp_dir = create_temp_project_without_pro()

      oban_configs = [
        %{
          name: Oban,
          app: :my_app,
          queues: [:default],
          plugins: [],
          insert_trigger: false,
          engine: nil,
          file: "config/config.exs",
          line: 10
        }
      ]

      context = %{oban_configs: oban_configs, project_root: tmp_dir}

      issues = SmartEngineNotConfigured.run(context)

      assert issues == []
    end

    test "detects multiple instances without SmartEngine" do
      tmp_dir = create_temp_project_with_pro()

      oban_configs = [
        %{
          name: Oban,
          app: :my_app,
          queues: [:default],
          plugins: [],
          insert_trigger: false,
          engine: Oban.Pro.Engines.Smart,
          file: "config/config.exs",
          line: 10
        },
        %{
          name: Reporting.Oban,
          app: :reporting,
          queues: [:sync],
          plugins: [],
          insert_trigger: false,
          engine: nil,
          file: "config/config.exs",
          line: 20
        },
        %{
          name: Mailer.Oban,
          app: :mailer,
          queues: [:protocol],
          plugins: [],
          insert_trigger: false,
          engine: Oban.Engines.Basic,
          file: "config/config.exs",
          line: 30
        }
      ]

      context = %{oban_configs: oban_configs, project_root: tmp_dir}

      issues = SmartEngineNotConfigured.run(context)

      assert length(issues) == 2
      instances = Enum.map(issues, & &1.meta.instance)
      assert Reporting.Oban in instances
      assert Mailer.Oban in instances
      refute Oban in instances
    end

    test "formats named instance correctly in message" do
      tmp_dir = create_temp_project_with_pro()

      oban_configs = [
        %{
          name: Reporting.Oban,
          app: :reporting,
          queues: [:sync],
          plugins: [],
          insert_trigger: false,
          engine: nil,
          file: "config/config.exs",
          line: 10
        }
      ]

      context = %{oban_configs: oban_configs, project_root: tmp_dir}

      issues = SmartEngineNotConfigured.run(context)

      assert length(issues) == 1
      [issue] = issues
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

  # Helper functions

  defp create_temp_project_with_pro do
    tmp_dir = Path.join(System.tmp_dir!(), "oban_doctor_pro_test_#{:rand.uniform(100_000)}")
    File.mkdir_p!(tmp_dir)

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
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    tmp_dir
  end

  defp create_temp_project_without_pro do
    tmp_dir = Path.join(System.tmp_dir!(), "oban_doctor_no_pro_test_#{:rand.uniform(100_000)}")
    File.mkdir_p!(tmp_dir)

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
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    tmp_dir
  end
end
