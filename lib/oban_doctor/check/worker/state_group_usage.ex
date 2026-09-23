defmodule ObanDoctor.Check.Worker.StateGroupUsage do
  @moduledoc """
  Checks for workers using the `:all` state group in unique configuration.

  Oban accepts named groups for `unique: [states: ...]`. See
  `ObanDoctor.UniqueStateGroups`,
  [`Oban.Job.unique_states/1`](https://hexdocs.pm/oban/Oban.Job.html#unique_states/1),
  and the [Unique Jobs guide](https://hexdocs.pm/oban/unique_jobs.html).

    * `:all` — every state, including `:completed`, `:cancelled`, and `:discarded`
    * `:successful` — Oban's default. Includes `:completed`, but not `:cancelled`
      or `:discarded`
    * `:incomplete` — jobs that have not finished
    * `:scheduled` — only `:scheduled`, for debouncing

  Using `states: :all` (or a list that contains `:all`) is dangerous because a
  completed, cancelled, or discarded job still counts as a duplicate. Another job
  with the same unique key cannot be enqueued until that row is gone.

  `:successful`, `:incomplete`, and `:scheduled` are valid groups and are not
  reported here. `:scheduled` can still miss in-progress states; that is reported
  by `ObanDoctor.Check.Worker.UniquenessMissingStates`.

  ## Examples

  Bad - blocks re-enqueueing after completion, cancellation, and discard:
      unique: [fields: [:args], states: :all]

  Good - named group for jobs that have not finished:
      unique: [fields: [:args], states: :incomplete]

  Also good - the same in-progress states written out explicitly:
      unique: [fields: [:args], states: [:available, :scheduled, :executing, :retryable]]
  """

  use ObanDoctor.Check, category: :worker

  alias ObanDoctor.UniqueStateGroups

  @impl true
  def id, do: :state_group_usage

  @impl true
  def description do
    "Detects workers using :all state group in unique config (dangerous)"
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
    unique
    |> Keyword.get(:states)
    |> UniqueStateGroups.referenced_groups()
    |> Enum.member?(:all)
  end

  defp uses_all_state_group?(_), do: false

  defp build_issue(worker) do
    Issue.new(
      check: __MODULE__,
      severity: default_severity(),
      message:
        "Worker #{inspect(worker.module)} uses :all state group - jobs cannot be re-enqueued after completion",
      file: worker.file,
      line: worker.line,
      meta: %{
        worker: worker.module,
        unique_config: worker.unique,
        state_group: :all,
        docs: UniqueStateGroups.doc_url()
      }
    )
  end
end
