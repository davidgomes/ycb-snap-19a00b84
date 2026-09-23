defmodule ObanDoctor.Check.Worker.StateGroupUsage do
  @moduledoc """
  Checks unique configuration for unsafe or invalid Oban named state groups.

  Oban accepts `states: :all | :incomplete | :scheduled | :successful`, or a
  list of individual job states. See `ObanDoctor.StateGroups`.

  Using `states: :all` includes `:completed`, `:discarded`, and `:cancelled`.
  Once a job finishes, another job with the same unique key can never be
  enqueued.

  A group name inside a list (`states: [:all]` or `states: [:incomplete]`) is
  invalid. Oban expects the group as an atom, or a list of real job states.

  ## Examples

  Bad - prevents re-enqueueing forever:
      unique: [fields: [:args], states: :all]

  Bad - group name passed inside a list:
      unique: [fields: [:args], states: [:incomplete]]

  Good - unique only while the job has not finished:
      unique: [fields: [:args], states: :incomplete]

  See the [Unique Jobs guide](https://oban.hexdocs.pm/unique_jobs.html)
  and [`Oban.Job.unique_states/1`](https://oban.hexdocs.pm/Oban.Job.html#unique_states/1).
  """

  use ObanDoctor.Check, category: :worker

  alias ObanDoctor.StateGroups

  @impl true
  def id, do: :state_group_usage

  @impl true
  def description do
    "Detects :all and other invalid Oban unique state groups"
  end

  @impl true
  def default_severity, do: :error

  @impl true
  def run(context) do
    workers = Map.get(context, :workers, [])

    Enum.flat_map(workers, &issues_for/1)
  end

  defp issues_for(%{unique: unique} = worker) when is_list(unique) do
    case Keyword.fetch(unique, :states) do
      {:ok, :all} ->
        [all_group_issue(worker)]

      {:ok, group} when is_atom(group) and not is_nil(group) ->
        if StateGroups.group?(group), do: [], else: [unknown_group_issue(worker, group)]

      {:ok, states} when is_list(states) ->
        case StateGroups.groups_in_list(states) do
          [] -> []
          groups -> [group_in_list_issue(worker, groups)]
        end

      _ ->
        []
    end
  end

  defp issues_for(_), do: []

  defp all_group_issue(worker) do
    build_issue(
      worker,
      "Worker #{inspect(worker.module)} uses :all state group - jobs cannot be re-enqueued after completion. See #{StateGroups.doc_url()}",
      %{state_group: :all, doc: StateGroups.doc_url()}
    )
  end

  defp unknown_group_issue(worker, group) do
    build_issue(
      worker,
      "Worker #{inspect(worker.module)} uses unknown unique state group #{inspect(group)}. Expected one of #{inspect(StateGroups.names())}. See #{StateGroups.unique_states_doc_url()}",
      %{state_group: group, doc: StateGroups.unique_states_doc_url()}
    )
  end

  defp group_in_list_issue(worker, groups) do
    build_issue(
      worker,
      "Worker #{inspect(worker.module)} passes named state group(s) #{inspect(groups)} inside a list. Use an atom such as states: :incomplete. See #{StateGroups.doc_url()}",
      %{state_groups: groups, doc: StateGroups.doc_url()}
    )
  end

  defp build_issue(worker, message, extra_meta) do
    Issue.new(
      check: __MODULE__,
      severity: default_severity(),
      message: message,
      file: worker.file,
      line: worker.line,
      meta:
        Map.merge(
          %{worker: worker.module, unique_config: worker.unique},
          extra_meta
        )
    )
  end
end
