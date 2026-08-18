defmodule ObanDoctor.Check.Worker.StateGroupUsage do
  @moduledoc """
  Checks for workers using a named state group that includes terminal states in
  unique configuration.

  Oban accepts either a list of individual states or one of the named groups
  `:all`, `:incomplete`, `:scheduled` and `:successful`. Two of those groups
  include terminal states:

    * `:all` includes `:completed`, `:cancelled` and `:discarded`
    * `:successful` (the default) includes `:completed`

  Once a job reaches a state covered by the group, another job with the same
  unique key can never be enqueued for the rest of the uniqueness period.

  ## Examples

  Bad - prevents re-enqueueing forever:
      unique: [fields: [:args], states: :all]

  Good - only considers jobs that haven't finished processing:
      unique: [fields: [:args], states: :incomplete]

  Good - explicit list of non-terminal states:
      unique: [fields: [:args], states: [:available, :scheduled, :executing, :retryable]]

  ## References

    * [Unique Jobs](https://hexdocs.pm/oban/unique_jobs.html)
    * [`Oban.Job.unique_states/1`](https://hexdocs.pm/oban/Oban.Job.html#unique_states/1)
  """

  use ObanDoctor.Check, category: :worker

  @docs_ref "https://hexdocs.pm/oban/unique_jobs.html#unique-options"

  @terminal_groups %{
    all: [:completed, :cancelled, :discarded],
    successful: [:completed]
  }

  @impl true
  def id, do: :state_group_usage

  @impl true
  def description do
    "Detects workers using a named state group that includes terminal states in unique config"
  end

  @impl true
  def default_severity, do: :error

  @impl true
  def run(context) do
    workers = Map.get(context, :workers, [])

    workers
    |> Enum.map(&{&1, terminal_group(&1)})
    |> Enum.reject(fn {_worker, group} -> is_nil(group) end)
    |> Enum.map(fn {worker, group} -> build_issue(worker, group) end)
  end

  defp terminal_group(%{unique: unique}) when is_list(unique) do
    case Keyword.get(unique, :states) do
      group when is_atom(group) -> if terminal_group?(group), do: group
      states when is_list(states) -> Enum.find(states, &terminal_group?/1)
      _ -> nil
    end
  end

  defp terminal_group(_), do: nil

  defp terminal_group?(group), do: Map.has_key?(@terminal_groups, group)

  # `:successful` is Oban's default group, so flagging it as an error would be
  # noisy. `:all` additionally covers cancelled and discarded jobs.
  defp severity(:all), do: default_severity()
  defp severity(_group), do: :warning

  defp build_issue(worker, group) do
    terminal_states = Map.fetch!(@terminal_groups, group)

    Issue.new(
      check: __MODULE__,
      severity: severity(group),
      message:
        "Worker #{inspect(worker.module)} uses #{inspect(group)} state group " <>
          "(includes #{Enum.map_join(terminal_states, ", ", &inspect/1)}) - " <>
          "jobs cannot be re-enqueued after completion. See #{@docs_ref}",
      file: worker.file,
      line: worker.line,
      meta: %{
        worker: worker.module,
        unique_config: worker.unique,
        state_group: group,
        terminal_states: terminal_states,
        docs: @docs_ref
      }
    )
  end
end
