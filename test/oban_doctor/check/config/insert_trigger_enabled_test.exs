defmodule ObanDoctor.Check.Config.InsertTriggerEnabledTest do
  use ExUnit.Case, async: true

  alias ObanDoctor.Check.Config.InsertTriggerEnabled

  describe "run/1" do
    test "returns warning when insert_trigger is not set" do
      oban_configs = [
        %{
          name: Oban,
          app: :my_app,
          queues: [:default],
          plugins: [],
          insert_trigger: nil,
          file: "config/config.exs",
          line: 10
        }
      ]

      context = %{oban_configs: oban_configs}

      issues = InsertTriggerEnabled.run(context)

      assert length(issues) == 1
      [issue] = issues
      assert issue.severity == :warning
      assert issue.check == InsertTriggerEnabled
      assert issue.message =~ "insert_trigger: false"
      assert issue.meta.instance == Oban
      assert issue.meta.app == :my_app
    end

    test "returns warning when insert_trigger is true" do
      oban_configs = [
        %{
          name: Oban,
          app: :my_app,
          queues: [:default],
          plugins: [],
          insert_trigger: true,
          file: "config/config.exs",
          line: 10
        }
      ]

      context = %{oban_configs: oban_configs}

      issues = InsertTriggerEnabled.run(context)

      assert length(issues) == 1
      [issue] = issues
      assert issue.severity == :warning
    end

    test "returns no issues when insert_trigger is false" do
      oban_configs = [
        %{
          name: Oban,
          app: :my_app,
          queues: [:default],
          plugins: [],
          insert_trigger: false,
          file: "config/config.exs",
          line: 10
        }
      ]

      context = %{oban_configs: oban_configs}

      issues = InsertTriggerEnabled.run(context)

      assert issues == []
    end

    test "detects multiple instances without insert_trigger disabled" do
      oban_configs = [
        %{
          name: Oban,
          app: :my_app,
          queues: [:default],
          plugins: [],
          insert_trigger: false,
          file: "config/config.exs",
          line: 10
        },
        %{
          name: Reporting.Oban,
          app: :reporting,
          queues: [:sync],
          plugins: [],
          insert_trigger: nil,
          file: "config/config.exs",
          line: 20
        },
        %{
          name: Mailer.Oban,
          app: :mailer,
          queues: [:protocol],
          plugins: [],
          insert_trigger: true,
          file: "config/config.exs",
          line: 30
        }
      ]

      context = %{oban_configs: oban_configs}

      issues = InsertTriggerEnabled.run(context)

      assert length(issues) == 2
      instances = Enum.map(issues, & &1.meta.instance)
      assert Reporting.Oban in instances
      assert Mailer.Oban in instances
      refute Oban in instances
    end

    test "formats named instance correctly in message" do
      oban_configs = [
        %{
          name: Reporting.Oban,
          app: :reporting,
          queues: [:sync],
          plugins: [],
          insert_trigger: nil,
          file: "config/config.exs",
          line: 10
        }
      ]

      context = %{oban_configs: oban_configs}

      issues = InsertTriggerEnabled.run(context)

      assert length(issues) == 1
      [issue] = issues
      assert issue.message =~ "Reporting.Oban"
    end
  end

  describe "id/0" do
    test "returns :insert_trigger_enabled" do
      assert InsertTriggerEnabled.id() == :insert_trigger_enabled
    end
  end

  describe "default_severity/0" do
    test "returns :warning" do
      assert InsertTriggerEnabled.default_severity() == :warning
    end
  end

  describe "category/0" do
    test "returns :config" do
      assert InsertTriggerEnabled.category() == :config
    end
  end
end
