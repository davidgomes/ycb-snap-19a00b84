defmodule ObanDoctor.Check.Config.SmartEngineNotConfigured do
  @moduledoc """
  Checks for Oban Pro instances that are not using `Oban.Pro.Engines.Smart`.

  The Smart engine is the recommended engine for Oban Pro. It replaces the
  Basic engine with global concurrency limits, queue partitioning, and more
  reliable job fetching under load.

  This check only runs when `:oban_pro` is listed as a dependency. Projects
  without Oban Pro cannot configure the Smart engine.

  ## How to fix

  Set the Smart engine on each Oban instance:

      config :my_app, Oban,
        engine: Oban.Pro.Engines.Smart,
        plugins: [Oban.Plugins.Pruner],
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
    "Detects Oban Pro instances not using Oban.Pro.Engines.Smart"
  end

  @impl true
  def default_severity, do: :warning

  @impl true
  def run(context) do
    if oban_pro?(context) do
      context
      |> Map.get(:oban_configs, [])
      |> Enum.reject(&smart_engine?/1)
      |> Enum.map(&build_issue/1)
    else
      []
    end
  end

  defp oban_pro?(context) do
    case Map.fetch(context, :has_oban_pro) do
      {:ok, value} when is_boolean(value) ->
        value

      _ ->
        case Map.get(context, :project_root) do
          root when is_binary(root) -> ObanDiscovery.has_oban_pro?(root)
          _ -> false
        end
    end
  end

  defp smart_engine?(%{engine: @smart_engine}), do: true
  defp smart_engine?(_), do: false

  defp build_issue(config) do
    instance_name = Helpers.format_instance_name(config.name)

    Issue.new(
      check: __MODULE__,
      severity: default_severity(),
      message: "Oban instance #{instance_name} is not using Oban.Pro.Engines.Smart",
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
