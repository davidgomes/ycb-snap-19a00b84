defmodule ObanDoctor.Check.Config.NoReindexer do
  @moduledoc """
  Checks for Oban instances without the Reindexer plugin configured.

  The Reindexer plugin periodically rebuilds indexes on the Oban jobs table
  to prevent index bloat and maintain query performance over time.

  Without periodic reindexing, indexes can become bloated, especially in
  high-throughput systems with frequent job insertions and completions.

  ## How to fix

  Add the Reindexer plugin to your Oban configuration:

      config :my_app, Oban,
        plugins: [
          Oban.Plugins.Pruner,
          Oban.Plugins.Reindexer
        ],
        queues: [default: 10]

  See [Oban Reindexer plugin](https://hexdocs.pm/oban/Oban.Plugins.Reindexer.html).

  ## Configuration

  In `.oban_doctor.exs`:

      checks: [
        no_reindexer: [
          # Disable the check entirely
          enabled: false,

          # Or exclude specific Oban instances from this check
          excluded_instances: [MyApp.SecondaryOban]
        ]
      ]
  """

  use ObanDoctor.Check, category: :config

  alias ObanDoctor.Check.Config.Helpers

  @impl true
  def id, do: :no_reindexer

  @impl true
  def description do
    "Detects Oban instances without the Reindexer plugin configured"
  end

  @impl true
  def default_severity, do: :warning

  @impl true
  def run(context) do
    context
    |> Map.get(:oban_configs, [])
    |> Helpers.find_configs_missing_plugin(&has_reindexer?/1, &build_issue/1)
  end

  defp has_reindexer?(%{plugins: plugins}) do
    Oban.Plugins.Reindexer in plugins
  end

  defp build_issue(config) do
    instance_name = Helpers.format_instance_name(config.name)

    Issue.new(
      check: __MODULE__,
      severity: default_severity(),
      message:
        "Oban instance #{instance_name} has no Reindexer plugin (indexes may become bloated)",
      file: config.file,
      line: config.line,
      meta: %{
        instance: config.name,
        app: config.app
      }
    )
  end
end
