defmodule ObanDoctor.Check.Worker.UniquenessMissingStates do
  @moduledoc """
  Checks explicit unique state lists for missing recommended states.

  When using an explicit state list, you should typically include all non-final
  states: `:available`, `:scheduled`, `:executing`, and `:retryable`.

  Missing states means duplicate jobs could be enqueued when existing jobs are
  in the missing state.

  Oban's named state groups (`:all`, `:incomplete`, `:scheduled`, and
  `:successful`) are intentional alternatives to explicit lists and aren't
  reported by this check. The `:all` group is handled by
  `ObanDoctor.Check.Worker.StateGroupUsage`.

  ## Examples

  Bad - only checks available state:
      unique: [fields: [:args], states: [:available]]

  Good - includes all non-final states:
      unique: [fields: [:args], states: [:available, :scheduled, :executing, :retryable]]

  Good - uses Oban's named group for unfinished jobs:
      unique: [fields: [:args], states: :incomplete]

  ## References

    * [Unique Jobs](https://hexdocs.pm/oban/unique_jobs.html)
    * [`Oban.Job.unique_states/1`](https://hexdocs.pm/oban/Oban.Job.html#unique_states/1)
    * [Upgrading to Oban v2.20](https://hexdocs.pm/oban/v2-20.html)
  """

  use ObanDoctor.Check, category: :worker

  @recommended_states [:available, :scheduled, :executing, :retryable]
  @named_state_groups [:all, :incomplete, :scheduled, :successful]

  @impl true
  def id, do: :uniqueness_missing_states

  @impl true
  def description do
    "Detects workers with explicit unique states missing recommended states"
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

    if uses_named_state_group?(states) do
      false
    else
      state_list = normalize_states(states)
      missing = @recommended_states -- state_list
      not Enum.empty?(missing)
    end
  end

  defp uses_named_state_group?(states) when states in @named_state_groups, do: true

  # Preserve support for the :all list form, which StateGroupUsage reports.
  defp uses_named_state_group?(states) when is_list(states), do: :all in states

  defp uses_named_state_group?(_), do: false

  defp normalize_states(states) when is_list(states), do: states
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
