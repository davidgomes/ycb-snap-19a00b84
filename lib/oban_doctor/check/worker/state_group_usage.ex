defmodule ObanDoctor.Check.Worker.StateGroupUsage do
  @moduledoc """
  Checks for workers using the `:all` state group in unique configuration.

  Oban provides named state groups for unique constraints:

    * `:successful` (default) - excludes cancelled/discarded, safe for most cases
    * `:incomplete` - only unfinished jobs, good for preventing concurrent execution
    * `:scheduled` - only scheduled jobs, useful for debouncing
    * `:all` - includes cancelled and discarded jobs (DANGEROUS)

  Using `states: :all` (or `states: [:all]`) in unique configuration is dangerous
  because it includes `:completed` and `:discarded` states. This means once a job
  completes or is discarded, you can never enqueue another job with the same
  unique key.

  ## Examples

  Bad - prevents re-enqueueing forever:
      unique: [fields: [:args], states: :all]

  Good - use a named group to prevent concurrent execution:
      unique: [fields: [:args], states: :incomplete]

  Good - explicit non-final states:
      unique: [fields: [:args], states: [:available, :scheduled, :executing, :retryable]]

  See [Oban unique jobs](https://hexdocs.pm/oban/unique_jobs.html).
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
        "Worker #{inspect(worker.module)} uses :all state group - jobs cannot be re-enqueued after completion",
      file: worker.file,
      line: worker.line,
      meta: %{
        worker: worker.module,
        unique_config: worker.unique
      }
    )
  end
end
