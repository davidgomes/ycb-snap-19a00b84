defmodule ObanDoctor.Check.Worker.StateGroupUsage do
  @moduledoc """
  Checks for workers using the `:all` named state group in unique configuration.

  Oban 2.20 accepts a named state group in place of an explicit state list:

    * `:incomplete` — jobs that have not finished (`:suspended`, `:available`,
      `:scheduled`, `:executing`, `:retryable`). Preferred when a finished job
      should be allowed to run again.
    * `:scheduled` — only `:scheduled` jobs, typically used to debounce.
    * `:successful` — incomplete states plus `:completed`. This is Oban's
      default and is not reported.
    * `:all` — every state, including `:completed`, `:discarded`, and
      `:cancelled`. Once any job with the same unique key finishes, another
      cannot be inserted.

  `states: :all`, `states: [:all]`, and a list that includes `:all` are reported
  as errors. The other named groups are recognized and left to
  `ObanDoctor.Check.Worker.UniquenessMissingStates` when they omit recommended
  states.

  ## Examples

  Bad — blocks re-enqueue after completion, discard, and cancel:

      unique: [fields: [:args], states: :all]

  Good — named group for jobs that have not finished:

      unique: [fields: [:args], states: :incomplete]

  Also good — the same non-final states written out explicitly:

      unique: [fields: [:args], states: [:available, :scheduled, :executing, :retryable]]

  ## References

    * [Oban.Job.unique_states/1](https://hexdocs.pm/oban/Oban.Job.html#unique_states/1)
    * [Unique Jobs](https://hexdocs.pm/oban/unique_jobs.html)
    * [Upgrading to v2.20 — Update Unique States](https://hexdocs.pm/oban/v2-20.html#update-unique-states-optional)
  """

  use ObanDoctor.Check, category: :worker

  alias ObanDoctor.UniqueStateGroups

  @impl true
  def id, do: :state_group_usage

  @impl true
  def description do
    "Detects workers using the :all named state group in unique config (dangerous)"
  end

  @impl true
  def default_severity, do: :error

  @impl true
  def run(context) do
    workers = Map.get(context, :workers, [])

    workers
    |> Enum.filter(&uses_all_state_group?/1)
    |> Enum.map(&build_issue/1)
  end

  defp uses_all_state_group?(%{unique: unique}) when is_list(unique) do
    states = Keyword.get(unique, :states)
    UniqueStateGroups.group_name(states) == :all or (is_list(states) and :all in states)
  end

  defp uses_all_state_group?(_), do: false

  defp build_issue(worker) do
    Issue.new(
      check: __MODULE__,
      severity: default_severity(),
      message:
        "Worker #{inspect(worker.module)} uses :all state group - jobs cannot be re-enqueued after completion. " <>
          "See #{UniqueStateGroups.unique_states_url()}",
      file: worker.file,
      line: worker.line,
      meta: %{
        worker: worker.module,
        unique_config: worker.unique,
        state_group: :all,
        docs: UniqueStateGroups.unique_states_url()
      }
    )
  end
end
