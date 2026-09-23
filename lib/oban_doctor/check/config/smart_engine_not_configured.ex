defmodule ObanDoctor.Check.Config.SmartEngineNotConfigured do
  @moduledoc """
  Checks for Oban instances that don't use the Smart engine when Oban Pro is installed.

  Oban Pro's Smart engine powers features such as global concurrency limits,
  rate limiting, queue partitioning, and unique bulk inserts. Without it, Oban
  uses the default `Oban.Engines.Basic` engine and those features are unavailable,
  even though Oban Pro is installed.

  This check only runs when `:oban_pro` is listed in your `mix.exs` dependencies
  (including umbrella apps). It flags instances with no `:engine` configured or
  with `engine: Oban.Engines.Basic`. Instances using a non-Postgres engine such as
  `Oban.Engines.Lite` or `Oban.Engines.Dolphin` are not flagged, since the Smart
  engine requires PostgreSQL.

  ## False Positives

  This check performs static analysis of your config files. It may report false
  positives if the engine is set dynamically (e.g., `engine: engine_for_env()`).

  ## How to fix

  Set the Smart engine in your Oban configuration:

      config :my_app, Oban,
        engine: Oban.Pro.Engines.Smart,
        queues: [default: 10]

  On Oban Pro v1.8+, the engine is named `Oban.Pro.Engine` (the old name still works).

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

  @non_smart_engines [nil, Oban.Engines.Basic]

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
      |> Enum.filter(&smart_engine_missing?/1)
      |> Enum.map(&build_issue/1)
    else
      []
    end
  end

  defp smart_engine_missing?(%{engine: engine}), do: engine in @non_smart_engines
  defp smart_engine_missing?(_), do: true

  defp build_issue(config) do
    instance_name = Helpers.format_instance_name(config.name)

    Issue.new(
      check: __MODULE__,
      severity: default_severity(),
      message:
        "Oban instance #{instance_name} does not use the Smart engine (Oban Pro features like global limits and rate limiting are unavailable)",
      file: config.file,
      line: config.line,
      meta: %{
        instance: config.name,
        app: config.app
      }
    )
  end
end
