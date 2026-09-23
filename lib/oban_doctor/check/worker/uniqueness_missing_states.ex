defmodule ObanDoctor.Check.Worker.UniquenessMissingStates do
  @moduledoc """
  Checks for workers with unique configuration that don't include every state
  from Oban's `:incomplete` group.

  When using unique constraints for in-flight jobs, include each state Oban
  puts in `:incomplete`: `:suspended`, `:available`, `:scheduled`, `:executing`,
  and `:retryable`. A missing state lets a duplicate be inserted while an
  existing job is in that state.

  Named groups are not flagged here:

    * `:incomplete` and `:successful` already cover every incomplete state
    * `:all` is reported by `ObanDoctor.Check.Worker.StateGroupUsage`
    * `:scheduled` (and the equivalent `[:scheduled]` list) is the debounce
      group from the Unique Jobs guide

  ## Examples

  Bad — only checks the available state:
      unique: [fields: [:args], states: [:available]]

  Good — the named incomplete group:
      unique: [fields: [:args], states: :incomplete]

  Also good — the same states written out:
      unique: [fields: [:args], states: [:suspended, :available, :scheduled, :executing, :retryable]]

  ## References

    * [Oban.Job.unique_states/1](https://hexdocs.pm/oban/Oban.Job.html#unique_states/1)
    * [Unique Jobs](https://hexdocs.pm/oban/unique_jobs.html)
  """

  use ObanDoctor.Check, category: :worker

  alias ObanDoctor.UniqueStateGroups

  @recommended_states UniqueStateGroups.incomplete_states()

  @impl true
  def id, do: :uniqueness_missing_states

  @impl true
  def description do
    "Detects workers with unique config missing states from the :incomplete group"
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
    states = Keyword.get(unique, :states)

    cond do
      UniqueStateGroups.intentional?(states) -> false
      is_atom(states) -> false
      true -> missing_states(states) != []
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
        "Worker #{inspect(worker.module)} unique config missing states: #{inspect(missing)}. " <>
          "See #{UniqueStateGroups.unique_states_doc()}",
      file: worker.file,
      line: worker.line,
      meta: %{
        worker: worker.module,
        configured_states: states,
        missing_states: missing,
        docs: UniqueStateGroups.doc_urls()
      }
    )
  end
end
