defmodule ObanDoctor.Check.Worker.StateGroupUsage do
  @moduledoc """
  Checks for workers using unsafe state groups in unique configuration.

  Using `:all` or `:final` (e.g. `states: :all` or `states: :final`) in unique configuration
  is dangerous because it includes `:completed` and/or `:discarded` / `:cancelled` states.
  This means once a job reaches a terminal state, you can never enqueue another job with
  the same unique key.

  ## State Groups in Oban

  Oban defines several named state groups:
  - `:all` - `[:available, :cancelled, :completed, :discarded, :executing, :retryable, :scheduled]` (Unsafe)
  - `:final` - `[:cancelled, :completed, :discarded]` (Unsafe)
  - `:active` - `[:available, :executing, :retryable, :scheduled]` (Safe / recommended)
  - `:executing` - `[:executing]`
  - `:historical` - `[:cancelled, :completed, :discarded]` (Unsafe, Pro)
  - `:scheduled` - `[:available, :retryable, :scheduled]`

  ## Examples

  Bad - prevents re-enqueueing forever:
      unique: [fields: [:args], states: :all]
      unique: [fields: [:args], states: :final]

  Good - allows re-enqueueing after completion:
      unique: [fields: [:args], states: :active]
      unique: [fields: [:args], states: [:available, :scheduled, :executing, :retryable]]

  ## References

  - [Oban Unique Jobs Documentation](https://hexdocs.pm/oban/Oban.Worker.html#module-unique-jobs)
  """

  use ObanDoctor.Check, category: :worker

  @doc_url "https://hexdocs.pm/oban/Oban.Worker.html#module-unique-jobs"

  @unsafe_state_groups [:all, :final, :historical]

  @impl true
  def id, do: :state_group_usage

  @impl true
  def description do
    "Detects workers using unsafe state groups (:all, :final, :historical) in unique config"
  end

  @impl true
  def default_severity, do: :error

  @impl true
  def run(context) do
    workers = Map.get(context, :workers, [])

    workers
    |> Enum.filter(&uses_unsafe_state_group?/1)
    |> Enum.map(&build_issue/1)
  end

  defp uses_unsafe_state_group?(%{unique: unique}) when is_list(unique) do
    case Keyword.get(unique, :states) do
      group when is_atom(group) -> group in @unsafe_state_groups
      [group] when is_atom(group) -> group in @unsafe_state_groups
      states when is_list(states) -> Enum.any?(states, &(&1 in @unsafe_state_groups))
      _ -> false
    end
  end

  defp uses_unsafe_state_group?(_), do: false

  defp extract_unsafe_group(%{unique: unique}) when is_list(unique) do
    case Keyword.get(unique, :states) do
      group when group in @unsafe_state_groups -> group
      [group] when group in @unsafe_state_groups -> group
      states when is_list(states) -> Enum.find(states, &(&1 in @unsafe_state_groups))
      _ -> nil
    end
  end

  defp extract_unsafe_group(_), do: nil

  defp build_issue(worker) do
    unsafe_group = extract_unsafe_group(worker)

    Issue.new(
      check: __MODULE__,
      severity: default_severity(),
      message:
        "Worker #{inspect(worker.module)} uses #{inspect(unsafe_group)} state group - jobs cannot be re-enqueued after reaching a terminal state. See #{@doc_url}",
      file: worker.file,
      line: worker.line,
      meta: %{
        worker: worker.module,
        unique_config: worker.unique,
        doc_url: @doc_url
      }
    )
  end
end
