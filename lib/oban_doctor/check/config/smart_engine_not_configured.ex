defmodule ObanDoctor.Check.Config.SmartEngineNotConfigured do
  @moduledoc """
  Checks for Oban instances that don't have SmartEngine configured when Oban Pro is installed.

  When using Oban Pro, configuring `engine: Oban.Pro.Engines.Smart` (or `Oban.Pro.Queue.SmartEngine`)
  is required to take full advantage of Pro features such as global concurrency limits, rate limiting,
  and partitioned queues.

  Without SmartEngine, Oban falls back to the standard `Oban.Engines.Basic` engine.

  This check only runs if `oban_pro` is detected in the project dependencies.

  ## How to fix

  Add `engine: Oban.Pro.Engines.Smart` to your Oban configuration:

      config :my_app, Oban,
        engine: Oban.Pro.Engines.Smart,
        queues: [default: 10]

  See [Oban Pro SmartEngine](https://hexdocs.pm/oban_pro/Oban.Pro.Engines.Smart.html) for more details.

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

  alias ObanDoctor.ObanDiscovery

  @smart_engines [
    Oban.Pro.Engines.Smart,
    Oban.Pro.Queue.SmartEngine
  ]

  @impl true
  def id, do: :smart_engine_not_configured

  @impl true
  def description do
    "Detects Oban instances without SmartEngine configured when Oban Pro is installed"
  end

  @impl true
  def default_severity, do: :warning

  @impl true
  def run(context) do
    project_root = Map.get(context, :project_root, File.cwd!())

    if ObanDiscovery.has_oban_pro?(project_root) do
      oban_configs = Map.get(context, :oban_configs, [])

      oban_configs
      |> Enum.filter(&missing_smart_engine?/1)
      |> Enum.map(&build_issue/1)
    else
      []
    end
  end

  defp missing_smart_engine?(%{engine: engine}) do
    engine not in @smart_engines
  end

  defp missing_smart_engine?(_), do: true

  defp build_issue(config) do
    instance_name = format_instance_name(config.name)

    Issue.new(
      check: __MODULE__,
      severity: default_severity(),
      message:
        "Oban instance #{instance_name} does not have SmartEngine configured while Oban Pro is in deps",
      file: config.file,
      line: config.line,
      meta: %{
        instance: config.name,
        app: config.app,
        engine: Map.get(config, :engine)
      }
    )
  end

  defp format_instance_name(Oban), do: "Oban"
  defp format_instance_name(name), do: inspect(name)
end
