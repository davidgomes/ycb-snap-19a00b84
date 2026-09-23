defmodule ObanDoctor.Check.Worker.UniquenessMissingStates do
  @moduledoc """
  Checks for workers with unique configuration that don't include all recommended states.

  When using a list of unique states, include every non-final state:
  `:available`, `:scheduled`, `:executing`, and `:retryable`. Missing states
  means a duplicate can be enqueued while an existing job is in the omitted
  state.

  Prefer a named group instead of a hand-written list. `:incomplete` covers
  jobs that have not finished (and, in current Oban, `:suspended`). `:all`,
  `:scheduled`, and `:successful` are also named groups and are not reported
  here. Invalid groups are reported by `ObanDoctor.Check.Worker.StateGroupUsage`.

  ## Examples

  Bad - only checks available state:
      unique: [fields: [:args], states: [:available]]

  Good - named group for in-progress jobs:
      unique: [fields: [:args], states: :incomplete]

  Also valid - explicit non-final states:
      unique: [fields: [:args], states: [:available, :scheduled, :executing, :retryable]]

  See the [Unique Jobs guide](https://oban.hexdocs.pm/unique_jobs.html)
  and [`Oban.Job.unique_states/1`](https://oban.hexdocs.pm/Oban.Job.html#unique_states/1).
  """

  use ObanDoctor.Check, category: :worker

  alias ObanDoctor.StateGroups

  @recommended_states [:available, :scheduled, :executing, :retryable]

  @impl true
  def id, do: :uniqueness_missing_states

  @impl true
  def description do
    "Detects unique state lists missing recommended states"
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
    states = Keyword.get(unique, :states)

    cond do
      named_group?(states) -> false
      group_inside_list?(states) -> false
      true -> not Enum.empty?(missing_states(states))
    end
  end

  defp named_group?(states) when is_atom(states) and not is_nil(states) do
    StateGroups.group?(states)
  end

  defp named_group?(_), do: false

  defp group_inside_list?(states) when is_list(states) do
    StateGroups.groups_in_list(states) != []
  end

  defp group_inside_list?(_), do: false

  defp missing_states(states) do
    @recommended_states -- normalize_states(states)
  end

  defp normalize_states(states) when is_list(states), do: states
  defp normalize_states(_), do: []

  defp build_issue(worker) do
    states = Keyword.get(worker.unique, :states, [])
    missing = missing_states(states)

    Issue.new(
      check: __MODULE__,
      severity: default_severity(),
      message:
        "Worker #{inspect(worker.module)} unique config missing states: #{inspect(missing)}. Prefer a named group such as :incomplete. See #{StateGroups.doc_url()}",
      file: worker.file,
      line: worker.line,
      meta: %{
        worker: worker.module,
        configured_states: states,
        missing_states: missing,
        doc: StateGroups.doc_url()
      }
    )
  end
end
