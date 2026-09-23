defmodule ObanDoctor.Check.Worker.StateGroupUsage do
  @moduledoc """
  Checks unique `:states` against Oban's named state groups.

  Using `states: :all` (or a list that includes `:all`) is dangerous because the
  group includes `:completed`, `:cancelled`, and `:discarded`. Once a job
  reaches one of those states, another job with the same unique key cannot be
  inserted until the old job is pruned.

  Other named groups are intentional:

    * `:incomplete` — unfinished jobs only, so completed work can be enqueued again
    * `:successful` — unfinished jobs plus `:completed` (Oban's default)
    * `:scheduled` — only scheduled jobs, for debouncing

  A named group must be passed as an atom. `states: [:incomplete]` is rejected
  by Oban because `:incomplete` is not a job state.

  ## Examples

  Bad — blocks re-enqueue after completion, cancellation, and discard:
      unique: [fields: [:args], states: :all]

  Good — uniqueness while the job has not finished:
      unique: [fields: [:args], states: :incomplete]

  ## References

    * [Oban.Job.unique_states/1](https://hexdocs.pm/oban/Oban.Job.html#unique_states/1)
    * [Unique Jobs](https://hexdocs.pm/oban/unique_jobs.html)
  """

  use ObanDoctor.Check, category: :worker

  alias ObanDoctor.UniqueStateGroups

  @impl true
  def id, do: :state_group_usage

  @impl true
  def description do
    "Detects workers using the :all unique state group, or an unknown group"
  end

  @impl true
  def default_severity, do: :error

  @impl true
  def run(context) do
    workers = Map.get(context, :workers, [])

    workers
    |> Enum.map(&classify/1)
    |> Enum.reject(&is_nil/1)
  end

  defp classify(%{unique: unique} = worker) when is_list(unique) do
    states = Keyword.get(unique, :states)

    cond do
      UniqueStateGroups.all_group?(states) ->
        build_issue(worker, all_group_message(worker))

      is_atom(states) and states != nil and not UniqueStateGroups.known?(states) ->
        build_issue(worker, unknown_group_message(worker, states))

      UniqueStateGroups.embedded_group?(states) ->
        build_issue(worker, embedded_group_message(worker))

      true ->
        nil
    end
  end

  defp classify(_worker), do: nil

  defp all_group_message(worker) do
    "Worker #{inspect(worker.module)} uses :all state group - jobs cannot be re-enqueued after completion. " <>
      doc_reference()
  end

  defp unknown_group_message(worker, group) do
    known = inspect(UniqueStateGroups.known_groups())

    "Worker #{inspect(worker.module)} uses unknown unique state group #{inspect(group)}. " <>
      "Expected one of #{known}. " <> doc_reference()
  end

  defp embedded_group_message(worker) do
    "Worker #{inspect(worker.module)} lists a named state group inside :states. " <>
      "Pass the group as an atom, for example states: :incomplete. " <> doc_reference()
  end

  defp doc_reference do
    "See #{UniqueStateGroups.unique_states_doc()}"
  end

  defp build_issue(worker, message) do
    Issue.new(
      check: __MODULE__,
      severity: default_severity(),
      message: message,
      file: worker.file,
      line: worker.line,
      meta: %{
        worker: worker.module,
        unique_config: worker.unique,
        docs: UniqueStateGroups.doc_urls()
      }
    )
  end
end
