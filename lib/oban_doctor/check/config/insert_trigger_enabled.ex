defmodule ObanDoctor.Check.Config.InsertTriggerEnabled do
  @moduledoc """
  Checks for Oban instances that have `insert_trigger` enabled (default behavior).

  The `insert_trigger` option causes Oban to notify queues via PostgreSQL NOTIFY
  whenever a job is inserted. While this enables faster job pickup, it adds
  overhead for high-volume job insertion.

  ## How to fix

  Add `insert_trigger: false` to your Oban configuration:

      config :my_app, Oban,
        insert_trigger: false,
        queues: [default: 10]

  > #### Warning {: .warning}
  >
  > Disabling the insert trigger means jobs may wait up to 1 second before being
  > picked up by a queue, as workers will rely on polling instead of notifications.

  See [Oban Triggers](https://hexdocs.pm/oban/scaling.html#triggers) for more details.

  ## Configuration

  In `.oban_doctor.exs`:

      checks: [
        insert_trigger_enabled: [
          # Disable the check entirely
          enabled: false,

          # Or exclude specific Oban instances from this check
          excluded_instances: [MyApp.SecondaryOban]
        ]
      ]
  """

  use ObanDoctor.Check, category: :config

  @impl true
  def id, do: :insert_trigger_enabled

  @impl true
  def description do
    "Detects Oban instances without insert_trigger explicitly disabled"
  end

  @impl true
  def default_severity, do: :warning

  @impl true
  def run(context) do
    oban_configs = Map.get(context, :oban_configs, [])

    oban_configs
    |> Enum.filter(&insert_trigger_not_disabled?/1)
    |> Enum.map(&build_issue/1)
  end

  defp insert_trigger_not_disabled?(%{insert_trigger: false}), do: false
  defp insert_trigger_not_disabled?(_), do: true

  defp build_issue(config) do
    instance_name = format_instance_name(config.name)

    Issue.new(
      check: __MODULE__,
      severity: default_severity(),
      message:
        "Oban instance #{instance_name} does not have insert_trigger: false set (performance overhead)",
      file: config.file,
      line: config.line,
      meta: %{
        instance: config.name,
        app: config.app
      }
    )
  end

  defp format_instance_name(Oban), do: "Oban"
  defp format_instance_name(name), do: inspect(name)
end
