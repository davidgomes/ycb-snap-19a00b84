defmodule ObanDoctor.Check.Config.SmartEngineNotConfigured do
  @moduledoc """
  Checks for Oban instances in projects using Oban Pro that don't configure
  the Smart engine.

  Most Oban Pro features (global concurrency, rate limiting, partitioning,
  batches, workflows, etc.) require `Oban.Pro.Engines.Smart`. Without it,
  Oban falls back to the basic engine and these features silently won't work.

  This check only runs when Oban Pro is detected, either as a dependency in
  `mix.exs` or via Oban Pro plugins in the instance configuration.

  ## How to fix

  Set the Smart engine in your Oban configuration:

      config :my_app, Oban,
        engine: Oban.Pro.Engines.Smart,
        queues: [default: 10]

  See [Oban Pro Smart Engine](https://oban.pro/docs/pro/Oban.Pro.Engines.Smart.html).

  ## Configuration

  In `.oban_doctor.exs`:

      checks: [
        smart_engine_not_configured: [
          # Disable the check entirely
          enabled: false,

          # Or exclude specific Oban instances from this check
          excluded_instances: [MyApp.SecondaryOban]
        ]
      ]
  """

  use ObanDoctor.Check, category: :config

  alias ObanDoctor.Check.Config.Helpers
  alias ObanDoctor.ObanDiscovery

  @smart_engine Oban.Pro.Engines.Smart

  @impl true
  def id, do: :smart_engine_not_configured

  @impl true
  def description do
    "Detects Oban Pro projects with instances not using the Smart engine"
  end

  @impl true
  def default_severity, do: :warning

  @impl true
  def run(context) do
    oban_configs = Map.get(context, :oban_configs, [])

    if uses_oban_pro?(context, oban_configs) do
      oban_configs
      |> Enum.reject(&(&1[:engine] == @smart_engine))
      |> Enum.map(&build_issue/1)
    else
      []
    end
  end

  defp uses_oban_pro?(context, oban_configs) do
    project_pro? =
      case Map.get(context, :project_root) do
        nil -> false
        root -> ObanDiscovery.has_oban_pro?(root)
      end

    project_pro? or Enum.any?(oban_configs, &has_pro_plugin?/1)
  end

  defp has_pro_plugin?(config) do
    config
    |> Map.get(:plugins, [])
    |> Enum.any?(&pro_module?/1)
  end

  defp pro_module?(module) do
    module
    |> Module.split()
    |> Enum.take(2) == ["Oban", "Pro"]
  end

  defp build_issue(config) do
    instance_name = Helpers.format_instance_name(config.name)

    Issue.new(
      check: __MODULE__,
      severity: default_severity(),
      message:
        "Oban instance #{instance_name} does not use Oban.Pro.Engines.Smart (Pro features require the Smart engine)",
      file: config.file,
      line: config.line,
      meta: %{
        instance: config.name,
        app: config.app,
        engine: config[:engine]
      }
    )
  end
end
