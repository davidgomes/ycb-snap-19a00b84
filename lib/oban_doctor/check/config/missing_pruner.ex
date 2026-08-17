defmodule ObanDoctor.Check.Config.MissingPruner do
  @moduledoc """
  Checks for Oban instances without a pruner plugin configured.

  Without a pruner, completed and discarded jobs accumulate in the database
  indefinitely, leading to storage growth and performance degradation over time.

  ## How to fix

  Add a pruner plugin to your Oban configuration:

      config :my_app, Oban,
        plugins: [
          {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7}  # 7 days
        ],
        queues: [default: 10]

  If using Oban Pro, you can use `Oban.Pro.Plugins.DynamicPruner` instead.

  See [Oban Pruner plugin](https://hexdocs.pm/oban/Oban.Plugins.Pruner.html).

  ## Configuration

  In `.oban_doctor.exs`:

      checks: [
        missing_pruner: [
          # Disable the check entirely
          enabled: false,

          # Or exclude specific Oban instances from this check
          excluded_instances: [MyApp.SecondaryOban]
        ]
      ]
  """

  use ObanDoctor.Check, category: :config

  alias ObanDoctor.Check.Config.Helpers

  @pruner_plugins [
    Oban.Plugins.Pruner,
    Oban.Pro.Plugins.DynamicPruner
  ]

  @impl true
  def id, do: :missing_pruner

  @impl true
  def description do
    "Detects Oban instances without a pruner plugin configured"
  end

  @impl true
  def default_severity, do: :warning

  @impl true
  def run(context) do
    context
    |> Map.get(:oban_configs, [])
    |> Helpers.find_configs_missing_plugin(&has_pruner?/1, &build_issue/1)
  end

  defp has_pruner?(%{plugins: plugins}) do
    Enum.any?(plugins, fn plugin -> plugin in @pruner_plugins end)
  end

  defp build_issue(config) do
    instance_name = Helpers.format_instance_name(config.name)

    Issue.new(
      check: __MODULE__,
      severity: default_severity(),
      message:
        "Oban instance #{instance_name} has no pruner plugin (jobs will accumulate indefinitely)",
      file: config.file,
      line: config.line,
      meta: %{
        instance: config.name,
        app: config.app
      }
    )
  end
end
