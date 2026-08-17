defmodule ObanDoctor.Check.Config.NoReindexerTest do
  use ExUnit.Case, async: true

  alias ObanDoctor.Check.Config.NoReindexer

  describe "run/1" do
    test "returns warning when no Reindexer plugin is configured" do
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

      issues = NoReindexer.run(context)

      assert length(issues) == 1
      [issue] = issues
      assert issue.severity == :warning
      assert issue.check == NoReindexer
      assert issue.message =~ "no Reindexer plugin"
      assert issue.meta.instance == Oban
      assert issue.meta.app == :my_app
    end

    test "returns no issues when Oban.Plugins.Reindexer is configured" do
      oban_configs = [
        %{
          name: Oban,
          app: :my_app,
          repo: MyApp.Repo,
          queues: [:default],
          plugins: [Oban.Plugins.Reindexer],
          insert_trigger: false,
          file: "config/config.exs",
          line: 10
        }
      ]

      context = %{oban_configs: oban_configs}

      issues = NoReindexer.run(context)

      assert issues == []
    end

    test "returns warning when plugins list is empty" do
      oban_configs = [
        %{
          name: Oban,
          app: :my_app,
          repo: MyApp.Repo,
          queues: [:default],
          plugins: [],
          insert_trigger: false,
          file: "config/config.exs",
          line: 10
        }
      ]

      context = %{oban_configs: oban_configs}

      issues = NoReindexer.run(context)

      assert length(issues) == 1
    end

    test "no issue when another instance with same repo has Reindexer" do
      oban_configs = [
        %{
          name: Oban,
          app: :my_app,
          repo: MyApp.Repo,
          queues: [:default],
          plugins: [Oban.Plugins.Reindexer],
          insert_trigger: false,
          file: "config/config.exs",
          line: 10
        },
        %{
          name: MyApp.SecondaryOban,
          app: :my_app,
          repo: MyApp.Repo,
          queues: [:sync],
          plugins: [Oban.Plugins.Pruner],
          insert_trigger: false,
          file: "config/config.exs",
          line: 20
        }
      ]

      context = %{oban_configs: oban_configs}

      issues = NoReindexer.run(context)

      # No issues - same repo, one instance has Reindexer
      assert issues == []
    end

    test "returns one issue per repo when no instance has Reindexer" do
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

      context = %{oban_configs: oban_configs}

      issues = NoReindexer.run(context)

      # Only one issue for the repo, not two
      assert length(issues) == 1
    end

    test "detects issues for different repos independently" do
      oban_configs = [
        %{
          name: Oban,
          app: :my_app,
          repo: MyApp.Repo,
          queues: [:default],
          plugins: [Oban.Plugins.Reindexer],
          insert_trigger: false,
          file: "config/config.exs",
          line: 10
        },
        %{
          name: Reporting.Oban,
          app: :reporting,
          repo: Reporting.Repo,
          queues: [:sync],
          plugins: [Oban.Plugins.Pruner],
          insert_trigger: false,
          file: "config/config.exs",
          line: 20
        }
      ]

      context = %{oban_configs: oban_configs}

      issues = NoReindexer.run(context)

      # Only Reporting.Repo is missing Reindexer
      assert length(issues) == 1
      [issue] = issues
      assert issue.meta.instance == Reporting.Oban
    end

    test "handles instances without repo (nil) individually" do
      oban_configs = [
        %{
          name: Oban,
          app: :my_app,
          repo: nil,
          queues: [:default],
          plugins: [Oban.Plugins.Pruner],
          insert_trigger: false,
          file: "config/config.exs",
          line: 10
        },
        %{
          name: Reporting.Oban,
          app: :reporting,
          repo: nil,
          queues: [:sync],
          plugins: [],
          insert_trigger: false,
          file: "config/config.exs",
          line: 20
        }
      ]

      context = %{oban_configs: oban_configs}

      issues = NoReindexer.run(context)

      # Both flagged individually since we can't determine if they share a repo
      assert length(issues) == 2
    end

    test "formats named instance correctly in message" do
      oban_configs = [
        %{
          name: Reporting.Oban,
          app: :reporting,
          repo: Reporting.Repo,
          queues: [:sync],
          plugins: [],
          insert_trigger: false,
          file: "config/config.exs",
          line: 10
        }
      ]

      context = %{oban_configs: oban_configs}

      issues = NoReindexer.run(context)

      assert length(issues) == 1
      [issue] = issues
      assert issue.message =~ "Reporting.Oban"
    end
  end

  describe "id/0" do
    test "returns :no_reindexer" do
      assert NoReindexer.id() == :no_reindexer
    end
  end

  describe "default_severity/0" do
    test "returns :warning" do
      assert NoReindexer.default_severity() == :warning
    end
  end

  describe "category/0" do
    test "returns :config" do
      assert NoReindexer.category() == :config
    end
  end
end
