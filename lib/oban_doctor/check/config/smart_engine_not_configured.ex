defmodule ObanDoctor.Check.Config.SmartEngineNotConfigured do
  @moduledoc """
  Checks if SmartEngine plugin is configured when Oban Pro is used.

  When `oban_pro` is a dependency in your project, using `Oban.Pro.Plugins.SmartEngine`
  is recommended instead of the default Basic engine. SmartEngine provides better
  producer concurrency, global partitioning, accurate rate limiting, and reduced database
  churn.

  ## How to fix

  Add `Oban.Pro.Plugins.SmartEngine` to your Oban plugins configuration:

      config :my_app, Oban,
        engine: Oban.Pro.Queue.SmartEngine,
        plugins: [
          Oban.Pro.Plugins.SmartEngine
        ],
        queues: [default: 10]

  See [Oban Pro SmartEngine](https://hexdocs.pm/oban_pro/Oban.Pro.Plugins.SmartEngine.html).

  ## Configuration

  In `.oban_doctor.exs`:

      checks: [
        smart_engine_not_configured: [
          # Disable the check entirely
          enabled: false
        ]
      ]
  """

  use ObanDoctor.Check, category: :config

  alias ObanDoctor.ObanDiscovery

  @smart_engine_plugin Oban.Pro.Plugins.SmartEngine

  @impl true
  def id, do: :smart_engine_not_configured

  @impl true
  def description do
    "Detects when Oban Pro is installed but SmartEngine is not configured"
  end

  @impl true
  def default_severity, do: :warning

  @impl true
  def run(context) do
    project_root = Map.get(context, :project_root)

    if project_root && ObanDiscovery.has_oban_pro?(project_root) do
      oban_configs = Map.get(context, :oban_configs, [])
      check_smart_engine(oban_configs)
    else
      []
    end
  end

  defp check_smart_engine([]), do: []

  defp check_smart_engine(oban_configs) do
    has_smart_engine? =
      Enum.any?(oban_configs, fn config ->
        @smart_engine_plugin in config.plugins
      end)

    if has_smart_engine? do
      []
    else
      # Report issue for the first Oban config
      [first_config | _] = oban_configs
      [build_issue(first_config)]
    end
  end

  defp build_issue(config) do
    Issue.new(
      check: __MODULE__,
      severity: default_severity(),
      message:
        "Oban Pro is a dependency but SmartEngine plugin is not configured in any Oban instance",
      file: config.file,
      line: config.line,
      meta: %{
        instance: config.name,
        app: config.app
      }
    )
  end
end
