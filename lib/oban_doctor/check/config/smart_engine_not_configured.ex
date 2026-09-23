defmodule ObanDoctor.Check.Config.SmartEngineNotConfigured do
  @moduledoc """
  Checks for Oban instances in Oban Pro projects that don't use the Smart engine.

  Many Oban Pro features (global concurrency, rate limiting, queue partitioning,
  unique job bulk inserts, etc.) require `Oban.Pro.Engines.Smart`. Without it,
  Oban falls back to the basic engine and those features silently don't work.

  This check only runs when `:oban_pro` is listed as a dependency in `mix.exs`.

  ## How to fix

  Set the engine in your Oban configuration:

      config :my_app, Oban,
        engine: Oban.Pro.Engines.Smart,
        queues: [default: 10]

  See [Smart Engine](https://oban.pro/docs/pro/Oban.Pro.Engines.Smart.html) for more details.

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

  import ObanDoctor.Check.Config.Helpers, only: [format_instance_name: 1]

  @smart_engine Oban.Pro.Engines.Smart

  @impl true
  def id, do: :smart_engine_not_configured

  @impl true
  def description do
    "Detects Oban Pro projects with instances not using Oban.Pro.Engines.Smart"
  end

  @impl true
  def default_severity, do: :warning

  @impl true
  def run(context) do
    if Map.get(context, :has_oban_pro, false) do
      context
      |> Map.get(:oban_configs, [])
      |> Enum.reject(&(Map.get(&1, :engine) == @smart_engine))
      |> Enum.map(&build_issue/1)
    else
      []
    end
  end

  defp build_issue(config) do
    instance_name = format_instance_name(config.name)

    Issue.new(
      check: __MODULE__,
      severity: default_severity(),
      message:
        "Oban instance #{instance_name} does not use Oban.Pro.Engines.Smart (Pro features require it)",
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
