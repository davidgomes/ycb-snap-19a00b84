defmodule ObanDoctor.Check.Worker.UniquenessMissingStates do
  @moduledoc """
  Checks for workers with unique configuration that don't include all recommended states.

  When using unique constraints, you should typically include all non-final states:
  `:available`, `:scheduled`, `:executing`, and `:retryable`.

  Missing states means duplicate jobs could be enqueued when existing jobs are
  in the missing state.

  Named state groups (`:all`, `:incomplete`, `:scheduled` and `:successful`) are
  expanded to the states they cover before comparing. The `:scheduled` group is
  skipped because it is the documented way to debounce jobs, and the `:all` and
  `:successful` groups are reported by
  `ObanDoctor.Check.Worker.StateGroupUsage` instead.

  ## Examples

  Bad - only checks available state:
      unique: [fields: [:args], states: [:available]]

  Good - includes all non-final states:
      unique: [fields: [:args], states: [:available, :scheduled, :executing, :retryable]]

  Good - the `:incomplete` group covers every non-final state:
      unique: [fields: [:args], states: :incomplete]

  ## References

    * [Unique Jobs](https://hexdocs.pm/oban/unique_jobs.html)
    * [`Oban.Job.unique_states/1`](https://hexdocs.pm/oban/Oban.Job.html#unique_states/1)
  """

  use ObanDoctor.Check, category: :worker

  @docs_ref "https://hexdocs.pm/oban/unique_jobs.html#unique-options"

  @recommended_states [:available, :scheduled, :executing, :retryable]

  # Mirrors `Oban.Job.unique_states/1`.
  @state_groups %{
    all: [
      :suspended,
      :scheduled,
      :available,
      :executing,
      :retryable,
      :completed,
      :discarded,
      :cancelled
    ],
    incomplete: [:suspended, :available, :scheduled, :executing, :retryable],
    scheduled: [:scheduled],
    successful: [:suspended, :available, :scheduled, :executing, :retryable, :completed]
  }

  # Groups reported by other checks, or intentional by design.
  @ignored_groups [:all, :successful, :scheduled]

  # `:scheduled` is both a group and a state name, so inside a list it is only
  # ever a state.
  @ignored_group_names @ignored_groups -- [:scheduled]

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
    |> Enum.reject(&ignored_group?/1)
    |> Enum.filter(&missing_recommended_states?/1)
    |> Enum.map(&build_issue/1)
  end

  defp has_unique_with_states?(%{unique: unique}) when is_list(unique) do
    Keyword.has_key?(unique, :states)
  end

  defp has_unique_with_states?(_), do: false

  defp ignored_group?(%{unique: unique}) do
    case Keyword.get(unique, :states) do
      group when is_atom(group) -> group in @ignored_groups
      states when is_list(states) -> Enum.any?(states, &(&1 in @ignored_group_names))
      _ -> false
    end
  end

  defp missing_recommended_states?(worker) do
    not Enum.empty?(missing_states(worker))
  end

  defp missing_states(%{unique: unique}) do
    states = Keyword.get(unique, :states, [])

    @recommended_states -- normalize_states(states)
  end

  defp normalize_states(states) when is_list(states) do
    Enum.flat_map(states, &normalize_states/1)
  end

  defp normalize_states(state) when is_atom(state), do: Map.get(@state_groups, state, [state])

  defp normalize_states(_), do: []

  defp build_issue(worker) do
    states = Keyword.get(worker.unique, :states, [])
    missing = missing_states(worker)

    Issue.new(
      check: __MODULE__,
      severity: default_severity(),
      message:
        "Worker #{inspect(worker.module)} unique config missing states: #{inspect(missing)}. " <>
          "See #{@docs_ref}",
      file: worker.file,
      line: worker.line,
      meta: %{
        worker: worker.module,
        configured_states: states,
        missing_states: missing,
        docs: @docs_ref
      }
    )
  end
end
