defmodule ObanDoctor.Check.Config.SmartEngineNotConfigured do
  @moduledoc """
  Checks for Oban instances not using Smart Engine when Oban Pro is installed.

  The Smart Engine (`Oban.Pro.Engines.Smart`) provides significant benefits over
  the Basic engine:

  - **Global concurrency limits** - Limit jobs across all nodes in a cluster
  - **Distributed rate limiting** - Control job execution rate across nodes
  - **Partitioned limiting** - Rate limit by partition (e.g., per-tenant)
  - **Enhanced unique job handling** - Faster, more reliable uniqueness via index
  - **Bulk inserts for unique jobs** - `insert_all/2` works with unique jobs
  - **Precise orphaned job rescuing** - More accurate detection and recovery

  This check only reports issues when Oban Pro is installed but not being used.
  If Oban Pro is not installed, no issues will be reported.

  ## How to fix

  Add `engine: Oban.Pro.Engines.Smart` to your Oban configuration:

      config :my_app, Oban,
        engine: Oban.Pro.Engines.Smart,
        repo: MyApp.Repo,
        queues: [default: 10]

  See [Oban Pro Smart Engine](https://getoban.pro/docs/pro/Oban.Pro.Engines.Smart.html).

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

  @impl true
  def id, do: :smart_engine_not_configured

  @impl true
  def description do
    "Detects Oban instances not using Smart Engine when Oban Pro is installed"
  end

  @impl true
  def default_severity, do: :info

  @impl true
  def run(context) do
    # Only check if Oban Pro is installed
    if Map.get(context, :has_oban_pro, false) do
      context
      |> Map.get(:oban_configs, [])
      |> Enum.filter(&not_using_smart_engine?/1)
      |> Enum.map(&build_issue/1)
    else
      []
    end
  end

  defp not_using_smart_engine?(%{engine: Oban.Pro.Engines.Smart}), do: false
  defp not_using_smart_engine?(_), do: true

  defp build_issue(config) do
    instance_name = Helpers.format_instance_name(config.name)

    Issue.new(
      check: __MODULE__,
      severity: default_severity(),
      message: "Oban instance #{instance_name} is not using Smart Engine (Oban Pro is installed)",
      file: config.file,
      line: config.line,
      meta: %{
        instance: config.name,
        app: config.app,
        current_engine: config.engine
      }
    )
  end
end
