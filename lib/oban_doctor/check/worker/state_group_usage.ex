defmodule ObanDoctor.Check.Worker.StateGroupUsage do
  @moduledoc """
  Checks for workers using the `:all` state group in unique configuration.

  Oban accepts named state groups for the unique `:states` option: `:all`,
  `:incomplete`, `:scheduled`, and `:successful` (the default). Unlike the other
  groups, `:all` also includes the `:cancelled` and `:discarded` states. This
  means a job that was cancelled or exhausted its attempts still blocks new jobs
  with the same unique key for the whole unique period, or forever with
  `period: :infinity`.

  ## Examples

  Bad - cancelled and discarded jobs block re-enqueueing:
      unique: [fields: [:args], states: :all]

  Good - only jobs that haven't finished processing block re-enqueueing:
      unique: [fields: [:args], states: :incomplete]

  Good - explicit list of non-final states:
      unique: [fields: [:args], states: [:available, :scheduled, :executing, :retryable]]
  """

  use ObanDoctor.Check, category: :worker

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
    case Keyword.get(unique, :states) do
      :all -> true
      [:all] -> true
      states when is_list(states) -> :all in states
      _ -> false
    end
  end

  defp uses_all_state_group?(_), do: false

  defp build_issue(worker) do
    Issue.new(
      check: __MODULE__,
      severity: default_severity(),
      message:
        "Worker #{inspect(worker.module)} uses :all state group - jobs cannot be re-enqueued after being cancelled or discarded",
      file: worker.file,
      line: worker.line,
      meta: %{
        worker: worker.module,
        unique_config: worker.unique
      }
    )
  end
end
