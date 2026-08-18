defmodule ObanDoctor.Check.Config.SmartEngineNotConfigured do
  @moduledoc """
  Checks for Oban instances not using Smart Engine when Oban Pro is installed.

  Smart Engine adds global concurrency limits, distributed rate limiting,
  partitioned limiting, and enhanced unique job handling. This check only
  reports issues when Oban Pro is installed.

  ## How to fix

  Add Smart Engine to your Oban configuration:

      config :my_app, Oban,
        engine: Oban.Pro.Engines.Smart,
        repo: MyApp.Repo,
        queues: [default: 10]

  See [Oban Pro Smart Engine](https://getoban.pro/docs/pro/Oban.Pro.Engines.Smart.html).

  ## Configuration

  In `.oban_doctor.exs`:

      checks: [
        smart_engine_not_configured: [
          enabled: false,
          excluded_instances: [MyApp.LegacyOban]
        ]
      ]
  """

  use ObanDoctor.Check, category: :config

  alias ObanDoctor.Check.Config.Helpers

  @impl true
  def id, do: :smart_engine_not_configured

  @impl true
  def description do
    "Detects Oban instances not using Smart Engine when Oban Pro is installed"
  end

  @impl true
  def default_severity, do: :info

  @impl true
  def run(context) do
    if Map.get(context, :has_oban_pro, false) do
      context
      |> Map.get(:oban_configs, [])
      |> Enum.reject(&using_smart_engine?/1)
      |> Enum.map(&build_issue/1)
    else
      []
    end
  end

  defp using_smart_engine?(%{engine: Oban.Pro.Engines.Smart}), do: true
  defp using_smart_engine?(_), do: false

  defp build_issue(config) do
    instance_name = Helpers.format_instance_name(config.name)

    Issue.new(
      check: __MODULE__,
      severity: default_severity(),
      message: "Oban instance #{instance_name} is not using Smart Engine (Oban Pro is installed)",
      file: config.file,
      line: config.line,
      meta: %{
        instance: config.name,
        app: config.app,
        current_engine: Map.get(config, :engine)
      }
    )
  end
end
