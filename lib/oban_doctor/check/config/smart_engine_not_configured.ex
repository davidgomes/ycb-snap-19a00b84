defmodule ObanDoctor.Check.Config.SmartEngineNotConfigured do
  @moduledoc """
  Checks for Oban instances not using the Smart engine while Oban Pro is installed.

  Oban Pro's Smart engine is a drop-in replacement for the Basic engine that
  unlocks global concurrency limits, rate limiting and more accurate job
  tracking. When Oban Pro is a dependency but an instance still runs on the
  Basic engine, those features are silently unavailable.

  This check only runs when `:oban_pro` is listed as a dependency in `mix.exs`.

  ## False Positives

  This check performs static analysis of your config files. It may report false
  positives if the engine is set outside of `config/*.exs`, for example when
  passing `engine: Oban.Pro.Engines.Smart` directly to `Oban.start_link/1`.

  ## How to fix

  Set the Smart engine in your Oban configuration:

      config :my_app, Oban,
        engine: Oban.Pro.Engines.Smart,
        queues: [default: 10]

  Note that the Smart engine requires the Pro migrations to be in place.

  See [Oban Pro Smart engine](https://oban.pro/docs/pro/Oban.Pro.Engines.Smart.html).

  ## Configuration

  In `.oban_doctor.exs`:

      checks: [
        smart_engine_not_configured: [
          # Disable the check entirely
          enabled: false,

          # Or exclude specific Oban instances from this check
          excluded_instances: [MyApp.LegacyOban]
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
    "Detects Oban instances not using the Smart engine when Oban Pro is installed"
  end

  @impl true
  def default_severity, do: :warning

  @impl true
  def run(context) do
    if oban_pro_installed?(context) do
      context
      |> Map.get(:oban_configs, [])
      |> Enum.reject(&smart_engine?/1)
      |> Enum.map(&build_issue/1)
    else
      []
    end
  end

  defp oban_pro_installed?(context) do
    case Map.get(context, :project_root) do
      nil -> false
      project_root -> ObanDiscovery.has_oban_pro?(project_root)
    end
  end

  defp smart_engine?(config) do
    Map.get(config, :engine) == @smart_engine
  end

  defp build_issue(config) do
    instance_name = Helpers.format_instance_name(config.name)

    Issue.new(
      check: __MODULE__,
      severity: default_severity(),
      message:
        "Oban instance #{instance_name} does not use Oban.Pro.Engines.Smart (Oban Pro features unavailable)",
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
