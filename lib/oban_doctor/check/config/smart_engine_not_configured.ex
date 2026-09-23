defmodule ObanDoctor.Check.Config.SmartEngineNotConfigured do
  @moduledoc """
  Checks for Oban instances that don't use the Smart engine in projects with Oban Pro.

  Oban Pro's Smart engine is required for many Pro features, such as global
  concurrency, rate limiting, queue partitioning, and bulk inserts. Without it,
  Oban falls back to the Basic engine and those features are unavailable.

  This check only runs when `:oban_pro` is listed as a dependency in `mix.exs`
  (including umbrella apps).

  ## How to fix

  Set the Smart engine in your Oban configuration:

      config :my_app, Oban,
        engine: Oban.Pro.Engines.Smart,
        queues: [default: 10]

  See [Oban Pro Smart engine](https://oban.pro/docs/pro/Oban.Pro.Engines.Smart.html).

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

  @smart_engines [
    Oban.Pro.Engines.Smart,
    Oban.Pro.Queue.SmartEngine
  ]

  @impl true
  def id, do: :smart_engine_not_configured

  @impl true
  def description do
    "Detects Oban instances not using the Smart engine when Oban Pro is installed"
  end

  @impl true
  def default_severity, do: :warning

  @impl true
  def run(context) do
    if Map.get(context, :has_oban_pro, false) do
      context
      |> Map.get(:oban_configs, [])
      |> Enum.reject(&smart_engine?/1)
      |> Enum.map(&build_issue/1)
    else
      []
    end
  end

  defp smart_engine?(config), do: Map.get(config, :engine) in @smart_engines

  defp build_issue(config) do
    instance_name = Helpers.format_instance_name(config.name)

    Issue.new(
      check: __MODULE__,
      severity: default_severity(),
      message:
        "Oban instance #{instance_name} does not use Oban.Pro.Engines.Smart (Pro features unavailable)",
      file: config.file,
      line: config.line,
      meta: %{
        instance: config.name,
        app: config.app,
        engine: Map.get(config, :engine)
      }
    )
  end
end
