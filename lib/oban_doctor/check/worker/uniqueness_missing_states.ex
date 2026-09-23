defmodule ObanDoctor.Check.Worker.UniquenessMissingStates do
  @moduledoc """
  Checks for workers with unique configuration that don't include all recommended states.

  When using unique constraints, you should typically include all non-final states:
  `:available`, `:scheduled`, `:executing`, and `:retryable`.

  Missing states means duplicate jobs could be enqueued when existing jobs are
  in the missing state.

  Oban's named state groups are expanded before comparison. `:incomplete` and
  `:successful` include every recommended state, while `:scheduled` only covers
  `[:scheduled]` and is flagged. The `:all` group is handled by
  `ObanDoctor.Check.Worker.StateGroupUsage`.

  ## Examples

  Bad - only checks available state:
      unique: [fields: [:args], states: [:available]]

  Bad - the `:scheduled` group only covers scheduled jobs:
      unique: [fields: [:args], states: :scheduled]

  Good - includes all non-final states:
      unique: [fields: [:args], states: [:available, :scheduled, :executing, :retryable]]

  Good - uses the `:incomplete` named group:
      unique: [fields: [:args], states: :incomplete]

  ## References

    * [Oban Unique Jobs guide](https://hexdocs.pm/oban/unique_jobs.html)
    * [`Oban.Job.unique_states/1`](https://hexdocs.pm/oban/Oban.Job.html#unique_states/1)
  """

  use ObanDoctor.Check, category: :worker

  @recommended_states [:available, :scheduled, :executing, :retryable]

  @named_state_groups %{
    incomplete: [:suspended, :available, :scheduled, :executing, :retryable],
    scheduled: [:scheduled],
    successful: [:suspended, :available, :scheduled, :executing, :retryable, :completed]
  }

  @impl true
  def id, do: :uniqueness_missing_states

  @impl true
  def description do
    "Detects workers with unique config missing recommended states"
  end

  @impl true
  def default_severity, do: :warning

  @impl true
  def run(context) do
    workers = Map.get(context, :workers, [])

    workers
    |> Enum.filter(&has_unique_with_states?/1)
    |> Enum.filter(&missing_recommended_states?/1)
    |> Enum.map(&build_issue/1)
  end

  defp has_unique_with_states?(%{unique: unique}) when is_list(unique) do
    Keyword.has_key?(unique, :states)
  end

  defp has_unique_with_states?(_), do: false

  defp missing_recommended_states?(%{unique: unique}) do
    states = Keyword.get(unique, :states, [])

    # Don't flag if they're using :all group (that's caught by another check)
    if uses_all_group?(states) do
      false
    else
      state_list = normalize_states(states)
      missing = @recommended_states -- state_list
      not Enum.empty?(missing)
    end
  end

  defp uses_all_group?(:all), do: true
  defp uses_all_group?([:all]), do: true
  defp uses_all_group?(states) when is_list(states), do: :all in states
  defp uses_all_group?(_), do: false

  defp normalize_states(states) when is_list(states), do: states

  defp normalize_states(group) when is_map_key(@named_state_groups, group),
    do: Map.fetch!(@named_state_groups, group)

  defp normalize_states(_), do: []

  defp build_issue(worker) do
    states = Keyword.get(worker.unique, :states, [])
    missing = @recommended_states -- normalize_states(states)

    Issue.new(
      check: __MODULE__,
      severity: default_severity(),
      message:
        "Worker #{inspect(worker.module)} unique config missing states: #{inspect(missing)}",
      file: worker.file,
      line: worker.line,
      meta: %{
        worker: worker.module,
        configured_states: states,
        missing_states: missing
      }
    )
  end
end
