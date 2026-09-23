defmodule ObanDoctor.Check.Worker.StateGroupUsage do
  @moduledoc """
  Checks for workers using unique state groups that include terminal states.

  Oban named groups are documented in
  [Unique Jobs](https://hexdocs.pm/oban/unique_jobs.html):

    * `:all` — every state, including `:completed`, `:cancelled`, and `:discarded`
    * `:completed` — `:completed`, `:cancelled`, and `:discarded`
    * `:incomplete` — `:available`, `:scheduled`, `:executing`, and `:retryable`

  Using `states: :all` or `states: :completed` (including the list forms) is
  dangerous because terminal states count toward uniqueness. Once a job
  completes, is cancelled, or is discarded, you cannot enqueue another job
  with the same unique key.

  ## Examples

  Bad — prevents re-enqueueing forever:

      unique: [fields: [:args], states: :all]
      unique: [fields: [:args], states: :completed]

  Good — allows re-enqueueing after completion:

      unique: [fields: [:args], states: :incomplete]
      unique: [fields: [:args], states: [:available, :scheduled, :executing, :retryable]]
  """

  use ObanDoctor.Check, category: :worker

  alias ObanDoctor.ObanStateGroups

  @impl true
  def id, do: :state_group_usage

  @impl true
  def description do
    "Detects workers using :all or :completed state groups in unique config (dangerous)"
  end

  @impl true
  def default_severity, do: :error

  @impl true
  def run(context) do
    workers = Map.get(context, :workers, [])

    workers
    |> Enum.filter(&uses_terminal_state_group?/1)
    |> Enum.map(&build_issue/1)
  end

  defp uses_terminal_state_group?(%{unique: unique}) when is_list(unique) do
    case Keyword.get(unique, :states) do
      nil -> false
      states -> ObanStateGroups.terminal_group?(states)
    end
  end

  defp uses_terminal_state_group?(_), do: false

  defp build_issue(worker) do
    states = Keyword.get(worker.unique, :states)
    groups = ObanStateGroups.named_groups(states)
    label = format_groups(groups, states)

    Issue.new(
      check: __MODULE__,
      severity: default_severity(),
      message:
        "Worker #{inspect(worker.module)} uses #{label} state group - jobs cannot be re-enqueued after completion",
      file: worker.file,
      line: worker.line,
      meta: %{
        worker: worker.module,
        unique_config: worker.unique,
        state_groups: groups
      }
    )
  end

  defp format_groups([], states), do: inspect(states)

  defp format_groups(groups, _states) do
    Enum.map_join(groups, ", ", &inspect/1)
  end
end
