defmodule ObanDoctor.ObanDiscoveryTest do
  use ExUnit.Case, async: true

  alias ObanDoctor.ObanDiscovery

  describe "discover_oban_configs/1" do
    test "discovers Oban config from config file" do
      # Create a temporary config file
      tmp_dir = create_temp_project()

      config_content = """
      import Config

      config :my_app, Oban,
        queues: [default: 10, emails: 5],
        plugins: [Oban.Plugins.Pruner, Oban.Plugins.Reindexer],
        insert_trigger: false
      """

      write_config(tmp_dir, "config/config.exs", config_content)

      configs = ObanDiscovery.discover_oban_configs(tmp_dir)

      assert length(configs) == 1
      [config] = configs

      assert config.name == Oban
      assert config.app == :my_app
      assert :default in config.queues
      assert :emails in config.queues
      assert Oban.Plugins.Pruner in config.plugins
      assert Oban.Plugins.Reindexer in config.plugins
      assert config.insert_trigger == false
      assert config.file == Path.join(tmp_dir, "config/config.exs")
    end

    test "discovers named Oban instance" do
      tmp_dir = create_temp_project()

      config_content = """
      import Config

      config :reporting, Oban,
        name: Reporting.Oban,
        queues: [sync: 5],
        plugins: []
      """

      write_config(tmp_dir, "config/config.exs", config_content)

      configs = ObanDiscovery.discover_oban_configs(tmp_dir)

      assert length(configs) == 1
      [config] = configs

      assert config.name == Reporting.Oban
      assert config.app == :reporting
    end

    test "discovers multiple Oban instances" do
      tmp_dir = create_temp_project()

      config_content = """
      import Config

      config :my_app, Oban,
        queues: [default: 10],
        plugins: [Oban.Plugins.Pruner],
        insert_trigger: false

      config :reporting, Oban,
        name: Reporting.Oban,
        queues: [sync: 5],
        plugins: []
      """

      write_config(tmp_dir, "config/config.exs", config_content)

      configs = ObanDiscovery.discover_oban_configs(tmp_dir)

      assert length(configs) == 2
      names = Enum.map(configs, & &1.name)
      assert Oban in names
      assert Reporting.Oban in names
    end

    test "extracts plugins with options" do
      tmp_dir = create_temp_project()

      config_content = """
      import Config

      config :my_app, Oban,
        queues: [default: 10],
        plugins: [
          {Oban.Plugins.Pruner, max_age: 60},
          {Oban.Plugins.Reindexer, schedule: "@weekly"}
        ]
      """

      write_config(tmp_dir, "config/config.exs", config_content)

      configs = ObanDiscovery.discover_oban_configs(tmp_dir)

      assert length(configs) == 1
      [config] = configs

      assert Oban.Plugins.Pruner in config.plugins
      assert Oban.Plugins.Reindexer in config.plugins
    end

    test "returns nil for insert_trigger when not set" do
      tmp_dir = create_temp_project()

      config_content = """
      import Config

      config :my_app, Oban,
        queues: [default: 10],
        plugins: []
      """

      write_config(tmp_dir, "config/config.exs", config_content)

      configs = ObanDiscovery.discover_oban_configs(tmp_dir)

      assert length(configs) == 1
      [config] = configs

      assert config.insert_trigger == nil
    end

    test "returns empty list when no config files exist" do
      tmp_dir = create_temp_project()
      configs = ObanDiscovery.discover_oban_configs(tmp_dir)
      assert configs == []
    end

    test "merges configs for same instance across files" do
      tmp_dir = create_temp_project()

      # Base config with insert_trigger: false and plugins
      config_content = """
      import Config

      config :my_app, Oban,
        queues: [default: 10],
        plugins: [Oban.Plugins.Pruner, Oban.Plugins.Reindexer],
        insert_trigger: false
      """

      # Runtime config adds more queues but doesn't set insert_trigger
      runtime_content = """
      import Config

      config :my_app, Oban,
        queues: [default: 10, emails: 5]
      """

      write_config(tmp_dir, "config/config.exs", config_content)
      write_config(tmp_dir, "config/runtime.exs", runtime_content)

      configs = ObanDiscovery.discover_oban_configs(tmp_dir)

      # Should be merged into a single instance
      assert length(configs) == 1
      [config] = configs

      assert config.name == Oban
      assert config.app == :my_app
      # insert_trigger from config.exs should be preserved
      assert config.insert_trigger == false
      # plugins from config.exs should be preserved (runtime.exs didn't override)
      assert Oban.Plugins.Pruner in config.plugins
      assert Oban.Plugins.Reindexer in config.plugins
      # queues from runtime.exs (later file wins)
      assert :default in config.queues
      assert :emails in config.queues
      # file/line should point to first definition
      assert config.file == Path.join(tmp_dir, "config/config.exs")
    end

    test "later insert_trigger value overrides earlier" do
      tmp_dir = create_temp_project()

      config_content = """
      import Config

      config :my_app, Oban,
        queues: [default: 10],
        plugins: [],
        insert_trigger: true
      """

      runtime_content = """
      import Config

      config :my_app, Oban,
        insert_trigger: false
      """

      write_config(tmp_dir, "config/config.exs", config_content)
      write_config(tmp_dir, "config/runtime.exs", runtime_content)

      configs = ObanDiscovery.discover_oban_configs(tmp_dir)

      assert length(configs) == 1
      [config] = configs

      # Later explicit value wins
      assert config.insert_trigger == false
    end

    test "keeps different instances separate when merging" do
      tmp_dir = create_temp_project()

      config_content = """
      import Config

      config :my_app, Oban,
        queues: [default: 10],
        plugins: [Oban.Plugins.Pruner],
        insert_trigger: false

      config :reporting, Oban,
        name: Reporting.Oban,
        queues: [sync: 5],
        plugins: []
      """

      runtime_content = """
      import Config

      config :my_app, Oban,
        queues: [default: 10, emails: 5]
      """

      write_config(tmp_dir, "config/config.exs", config_content)
      write_config(tmp_dir, "config/runtime.exs", runtime_content)

      configs = ObanDiscovery.discover_oban_configs(tmp_dir)

      # Should have 2 instances (my_app/Oban and reporting/Reporting.Oban)
      assert length(configs) == 2

      main_config = Enum.find(configs, &(&1.app == :my_app))
      reporting_config = Enum.find(configs, &(&1.app == :reporting))

      # my_app/Oban should have merged config
      assert main_config.insert_trigger == false
      assert :emails in main_config.queues

      # reporting/Reporting.Oban should be unchanged
      assert reporting_config.name == Reporting.Oban
      assert reporting_config.queues == [:sync]
    end
  end

  describe "discover_queues/1" do
    test "returns MapSet of all queues from all instances" do
      tmp_dir = create_temp_project()

      config_content = """
      import Config

      config :my_app, Oban,
        queues: [default: 10, emails: 5],
        plugins: []

      config :reporting, Oban,
        name: Reporting.Oban,
        queues: [sync: 5, imports: 2],
        plugins: []
      """

      write_config(tmp_dir, "config/config.exs", config_content)

      queues = ObanDiscovery.discover_queues(tmp_dir)

      assert MapSet.member?(queues, :default)
      assert MapSet.member?(queues, :emails)
      assert MapSet.member?(queues, :sync)
      assert MapSet.member?(queues, :imports)
    end
  end

  describe "has_oban_pro?/1" do
    test "returns true when oban_pro is in deps" do
      tmp_dir = create_temp_project()

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

      assert ObanDiscovery.has_oban_pro?(tmp_dir) == true
    end

    test "returns false when oban_pro is not in deps" do
      tmp_dir = create_temp_project()

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

      assert ObanDiscovery.has_oban_pro?(tmp_dir) == false
    end

    test "returns false when mix.exs does not exist" do
      tmp_dir = create_temp_project()
      assert ObanDiscovery.has_oban_pro?(tmp_dir) == false
    end
  end

  describe "error handling" do
    test "handles config file with syntax errors gracefully" do
      tmp_dir = create_temp_project()

      # Write invalid syntax
      config_content = """
      import Config

      config :my_app, Oban,
        queues: [default: 10
      """

      write_config(tmp_dir, "config/config.exs", config_content)

      # Should return empty list, not crash
      configs = ObanDiscovery.discover_oban_configs(tmp_dir)
      assert configs == []
    end

    test "handles unreadable config file gracefully" do
      tmp_dir = create_temp_project()
      config_path = Path.join(tmp_dir, "config/config.exs")
      File.mkdir_p!(Path.dirname(config_path))
      File.write!(config_path, "import Config\nconfig :my_app, Oban, queues: [default: 10]")
      File.chmod!(config_path, 0o000)

      # Should return empty list, not crash
      configs = ObanDiscovery.discover_oban_configs(tmp_dir)
      assert configs == []

      # Restore permissions for cleanup
      File.chmod!(config_path, 0o644)
    end
  end

  describe "edge cases" do
    test "handles name as raw atom" do
      tmp_dir = create_temp_project()

      # Use a raw atom for name (not an alias)
      config_content = """
      import Config

      config :my_app, Oban,
        name: :my_oban,
        queues: [default: 10],
        plugins: []
      """

      write_config(tmp_dir, "config/config.exs", config_content)

      configs = ObanDiscovery.discover_oban_configs(tmp_dir)

      assert length(configs) == 1
      [config] = configs
      assert config.name == :my_oban
    end

    test "handles empty queues list" do
      tmp_dir = create_temp_project()

      config_content = """
      import Config

      config :my_app, Oban,
        queues: [],
        plugins: []
      """

      write_config(tmp_dir, "config/config.exs", config_content)

      configs = ObanDiscovery.discover_oban_configs(tmp_dir)

      assert length(configs) == 1
      [config] = configs
      assert config.queues == []
    end

    test "handles plugins as raw atoms" do
      tmp_dir = create_temp_project()

      config_content = """
      import Config

      config :my_app, Oban,
        queues: [default: 10],
        plugins: [SomePlugin]
      """

      write_config(tmp_dir, "config/config.exs", config_content)

      configs = ObanDiscovery.discover_oban_configs(tmp_dir)

      assert length(configs) == 1
      [config] = configs
      # SomePlugin is parsed as an alias, not a raw atom
      assert SomePlugin in config.plugins
    end

    test "handles false name value" do
      tmp_dir = create_temp_project()

      # Name can be false to disable the supervisor
      config_content = """
      import Config

      config :my_app, Oban,
        name: false,
        queues: [default: 10],
        plugins: []
      """

      write_config(tmp_dir, "config/config.exs", config_content)

      configs = ObanDiscovery.discover_oban_configs(tmp_dir)

      assert length(configs) == 1
      [config] = configs
      # false is an atom, so it gets preserved as the name
      assert config.name == false
    end

    test "extracts all valid queue names" do
      tmp_dir = create_temp_project()

      config_content = """
      import Config

      config :my_app, Oban,
        queues: [default: 10, emails: 5, reports: 2],
        plugins: []
      """

      write_config(tmp_dir, "config/config.exs", config_content)

      configs = ObanDiscovery.discover_oban_configs(tmp_dir)

      assert length(configs) == 1
      [config] = configs
      assert :default in config.queues
      assert :emails in config.queues
      assert :reports in config.queues
    end

    test "handles plugins with tuple AST form" do
      tmp_dir = create_temp_project()

      # This creates the {:{}, _, [...]} AST form in some cases
      config_content = """
      import Config

      config :my_app, Oban,
        queues: [default: 10],
        plugins: [
          {Oban.Plugins.Pruner, max_age: 60, limit: 100, interval: 1000}
        ]
      """

      write_config(tmp_dir, "config/config.exs", config_content)

      configs = ObanDiscovery.discover_oban_configs(tmp_dir)

      assert length(configs) == 1
      [config] = configs
      assert Oban.Plugins.Pruner in config.plugins
    end

    test "extracts plugins from list concatenation with dynamic part" do
      tmp_dir = create_temp_project()

      # This is common in runtime.exs: static plugins ++ conditional plugins
      config_content = """
      import Config

      is_prod? = config_env() == :prod

      config :my_app, Oban,
        queues: [default: 10],
        plugins:
          [
            Oban.Plugins.Pruner,
            {Oban.Plugins.Reindexer, schedule: "@weekly"}
          ] ++
            if(is_prod?,
              do: [Oban.Plugins.SomeProPlugin],
              else: []
            )
      """

      write_config(tmp_dir, "config/runtime.exs", config_content)

      configs = ObanDiscovery.discover_oban_configs(tmp_dir)

      assert length(configs) == 1
      [config] = configs
      # Should extract plugins from the static part of the concatenation
      assert Oban.Plugins.Pruner in config.plugins
      assert Oban.Plugins.Reindexer in config.plugins
    end

    test "extracts repo from config" do
      tmp_dir = create_temp_project()

      config_content = """
      import Config

      config :my_app, Oban,
        repo: MyApp.Repo,
        queues: [default: 10],
        plugins: []
      """

      write_config(tmp_dir, "config/config.exs", config_content)

      configs = ObanDiscovery.discover_oban_configs(tmp_dir)

      assert length(configs) == 1
      [config] = configs
      assert config.repo == MyApp.Repo
    end

    test "returns nil repo when not set" do
      tmp_dir = create_temp_project()

      config_content = """
      import Config

      config :my_app, Oban,
        queues: [default: 10],
        plugins: []
      """

      write_config(tmp_dir, "config/config.exs", config_content)

      configs = ObanDiscovery.discover_oban_configs(tmp_dir)

      assert length(configs) == 1
      [config] = configs
      assert config.repo == nil
    end

    test "merges repo across config files" do
      tmp_dir = create_temp_project()

      config_content = """
      import Config

      config :my_app, Oban,
        repo: MyApp.Repo,
        queues: [default: 10],
        plugins: []
      """

      runtime_content = """
      import Config

      config :my_app, Oban,
        queues: [default: 10, emails: 5]
      """

      write_config(tmp_dir, "config/config.exs", config_content)
      write_config(tmp_dir, "config/runtime.exs", runtime_content)

      configs = ObanDiscovery.discover_oban_configs(tmp_dir)

      assert length(configs) == 1
      [config] = configs
      # repo from config.exs should be preserved
      assert config.repo == MyApp.Repo
    end
  end

  # Helper functions

  defp create_temp_project do
    tmp_dir = Path.join(System.tmp_dir!(), "oban_doctor_test_#{:rand.uniform(100_000)}")
    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    tmp_dir
  end

  defp write_config(root, relative_path, content) do
    full_path = Path.join(root, relative_path)
    File.mkdir_p!(Path.dirname(full_path))
    File.write!(full_path, content)
  end
end
