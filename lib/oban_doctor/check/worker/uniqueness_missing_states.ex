defmodule ObanDoctor.Check.Worker.UniquenessMissingStates do
  @moduledoc """
  Checks for workers with unique configuration that don't include all recommended states.

  When using unique constraints, you should typically include all non-final states:
  `:available`, `:scheduled`, `:executing`, and `:retryable`.

  Missing states means duplicate jobs could be enqueued when existing jobs are
  in the missing state.

  Oban also accepts named state groups. This check expands them with
  `ObanDoctor.UniqueStateGroups` before comparing, matching
  [`Oban.Job.unique_states/1`](https://hexdocs.pm/oban/Oban.Job.html#unique_states/1).
  See the [Unique Jobs guide](https://hexdocs.pm/oban/unique_jobs.html) for when to
  pick a group.

    * `:incomplete` and `:successful` include the recommended states
    * `:all` includes them too, and is reported separately by
      `ObanDoctor.Check.Worker.StateGroupUsage`
    * `:scheduled` is only `:scheduled`, so the other recommended states are missing

  ## Examples

  Bad - only checks available state:
      unique: [fields: [:args], states: [:available]]

  Good - named group for jobs that have not finished:
      unique: [fields: [:args], states: :incomplete]

  Also good - includes all non-final states explicitly:
      unique: [fields: [:args], states: [:available, :scheduled, :executing, :retryable]]
  """

  use ObanDoctor.Check, category: :worker

  alias ObanDoctor.UniqueStateGroups

  @recommended_states [:available, :scheduled, :executing, :retryable]

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
    unique
    |> Keyword.get(:states)
    |> missing_states()
    |> case do
      [] -> false
      _missing -> true
    end
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
        "Worker #{inspect(worker.module)} unique config missing states: #{inspect(missing)}",
      file: worker.file,
      line: worker.line,
      meta: %{
        worker: worker.module,
        configured_states: states,
        missing_states: missing,
        docs: UniqueStateGroups.doc_url()
      }
    )
  end
end
