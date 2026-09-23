defmodule ObanDoctor.Check.Config.SmartEngineNotConfigured do
  @moduledoc """
  Checks for Oban instances not using the Smart Engine when Oban Pro is installed.

  The Smart Engine (`Oban.Pro.Engines.Smart`) provides significant benefits over
  the Basic engine:

  - **Global concurrency limits** - Limit jobs across all nodes in a cluster
  - **Distributed rate limiting** - Control job execution rate across nodes
  - **Partitioned limiting** - Rate limit by partition (e.g., per-tenant)
  - **Enhanced unique job handling** - Faster, more reliable uniqueness
  - **Bulk inserts for unique jobs** - `insert_all/2` works with unique jobs
  - **Precise orphaned job rescuing** - More accurate detection and recovery

  This check only reports issues when `:oban_pro` is a dependency of the project.
  If Oban Pro is not installed, no issues are reported.

  ## How to fix

  Add `engine: Oban.Pro.Engines.Smart` to your Oban configuration:

      config :my_app, Oban,
        engine: Oban.Pro.Engines.Smart,
        repo: MyApp.Repo,
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

  @smart_engine Oban.Pro.Engines.Smart

  @impl true
  def id, do: :smart_engine_not_configured

  @impl true
  def description do
    "Detects Oban instances not using the Smart Engine when Oban Pro is installed"
  end

  @impl true
  def default_severity, do: :info

  @impl true
  def run(context) do
    if Map.get(context, :has_oban_pro, false) do
      context
      |> Map.get(:oban_configs, [])
      |> Enum.reject(&using_smart_engine?/1)
      |> Enum.map(&build_issue/1)
    else
      []
    end
  end

  defp using_smart_engine?(config), do: Map.get(config, :engine) == @smart_engine

  defp build_issue(config) do
    instance_name = Helpers.format_instance_name(config.name)

    Issue.new(
      check: __MODULE__,
      severity: default_severity(),
      message:
        "Oban instance #{instance_name} is not using the Smart Engine (Oban Pro is installed)",
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
