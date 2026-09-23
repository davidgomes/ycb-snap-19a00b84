defmodule ObanDoctor.Check.Config.SmartEngineNotConfigured do
  @moduledoc """
  Checks for Oban Pro projects that do not use `Oban.Pro.Engines.Smart`.

  The Smart engine is required for Oban Pro features such as global
  concurrency limits, rate limiting, and queue partitioning. The default
  `Oban.Engines.Basic` engine ignores those options.

  Projects that do not depend on `:oban_pro` are skipped.

  ## How to fix

  Set the Smart engine on each Oban instance:

      config :my_app, Oban,
        engine: Oban.Pro.Engines.Smart,
        queues: [default: 10]

  See [Oban Pro Smart Engine](https://getoban.pro/docs/pro/smart_engine.html).

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
    if pro_available?(context) do
      context
      |> Map.get(:oban_configs, [])
      |> Enum.reject(&smart_engine?/1)
      |> Enum.map(&build_issue/1)
    else
      []
    end
  end

  defp pro_available?(%{has_oban_pro: value}) when is_boolean(value), do: value

  defp pro_available?(%{project_root: root}) when is_binary(root) do
    ObanDiscovery.has_oban_pro?(root)
  end

  defp pro_available?(_), do: false

  defp smart_engine?(%{engine: @smart_engine}), do: true
  defp smart_engine?(_), do: false

  defp build_issue(config) do
    instance_name = format_instance_name(config.name)

    Issue.new(
      check: __MODULE__,
      severity: default_severity(),
      message:
        "Oban instance #{instance_name} is not configured to use Oban.Pro.Engines.Smart",
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
