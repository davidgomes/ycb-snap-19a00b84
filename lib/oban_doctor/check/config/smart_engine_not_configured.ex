defmodule ObanDoctor.Check.Config.SmartEngineNotConfigured do
  @moduledoc """
  Checks for Oban instances that aren't using the Smart engine when Oban Pro is installed.

  Oban Pro's Smart engine replaces Oban's default `Oban.Engines.Basic` engine and
  powers many Pro features, such as global concurrency limits, rate limiting,
  queue partitioning, async tracking, accurate snoozes, and unique bulk inserts.
  Without it, those features are unavailable even though Oban Pro is installed.

  This check only runs when `:oban_pro` is a dependency in `mix.exs` (including
  umbrella apps). Only instances using the Basic engine, either implicitly or
  explicitly, are flagged. Instances configured with another engine, such as
  `Oban.Engines.Lite` (SQLite) or `Oban.Engines.Dolphin` (MySQL), are skipped
  because the Smart engine only supports PostgreSQL.

  ## How to fix

  Set the Smart engine in your Oban configuration:

      config :my_app, Oban,
        engine: Oban.Pro.Engines.Smart,
        repo: MyApp.Repo,
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

  @basic_engines [nil, Oban.Engines.Basic]

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
      |> Enum.filter(&basic_engine?/1)
      |> Enum.map(&build_issue/1)
    else
      []
    end
  end

  defp basic_engine?(config), do: Map.get(config, :engine) in @basic_engines

  defp build_issue(config) do
    instance_name = Helpers.format_instance_name(config.name)

    Issue.new(
      check: __MODULE__,
      severity: default_severity(),
      message:
        "Oban instance #{instance_name} is not using the Smart engine (Oban Pro features like global limits and rate limiting are unavailable)",
      file: config.file,
      line: config.line,
      meta: %{
        instance: config.name,
        app: config.app
      }
    )
  end
end
