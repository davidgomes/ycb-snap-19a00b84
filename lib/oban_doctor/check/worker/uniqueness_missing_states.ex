defmodule ObanDoctor.Check.Worker.UniquenessMissingStates do
  @moduledoc """
  Checks for workers with unique configuration that don't include all recommended states.

  When using unique constraints, include every non-final state so an in-progress
  job still counts as a duplicate: `:available`, `:scheduled`, `:executing`, and
  `:retryable`.

  Named state groups are expanded before that comparison:

    * `:incomplete` and `:successful` include the recommended states
    * `:all` is ignored here and reported by `ObanDoctor.Check.Worker.StateGroupUsage`
    * `:scheduled` only covers `:scheduled`, so the other recommended states are
      still reported as missing

  A single-element list such as `[:incomplete]` is treated as that named group.

  ## Examples

  Bad — only checks the available state:

      unique: [fields: [:args], states: [:available]]

  Good — named group for jobs that have not finished:

      unique: [fields: [:args], states: :incomplete]

  Also good — explicit non-final states:

      unique: [fields: [:args], states: [:available, :scheduled, :executing, :retryable]]

  ## References

    * [Oban.Job.unique_states/1](https://hexdocs.pm/oban/Oban.Job.html#unique_states/1)
    * [Unique Jobs](https://hexdocs.pm/oban/unique_jobs.html)
    * [Upgrading to v2.20 — Update Unique States](https://hexdocs.pm/oban/v2-20.html#update-unique-states-optional)
  """

  use ObanDoctor.Check, category: :worker

  alias ObanDoctor.UniqueStateGroups

  @recommended_states [:available, :scheduled, :executing, :retryable]

  @impl true
  def id, do: :uniqueness_missing_states

  @impl true
  def description do
    "Detects unique configs missing recommended states (named state groups are expanded)"
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

    # :all is reported by StateGroupUsage, including when mixed into a list.
    if uses_all_group?(states) do
      false
    else
      not Enum.empty?(missing_states(states))
    end
  end

  defp uses_all_group?(states) do
    UniqueStateGroups.group_name(states) == :all or (is_list(states) and :all in states)
  end

  defp missing_states(states) do
    @recommended_states -- UniqueStateGroups.expand(states)
  end

  defp build_issue(worker) do
    states = Keyword.get(worker.unique, :states, [])
    missing = missing_states(states)

    Issue.new(
      check: __MODULE__,
      severity: default_severity(),
      message:
        "Worker #{inspect(worker.module)} unique config missing states: #{inspect(missing)}. " <>
          "See #{UniqueStateGroups.unique_states_url()}",
      file: worker.file,
      line: worker.line,
      meta: %{
        worker: worker.module,
        configured_states: states,
        missing_states: missing,
        state_group: UniqueStateGroups.group_name(states),
        docs: UniqueStateGroups.unique_states_url()
      }
    )
  end
end
