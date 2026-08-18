defmodule ObanDoctor.Check.Worker.UniquenessMissingStates do
  @moduledoc """
  Checks for workers with unique configuration that don't include all recommended states.

  When using unique constraints, you should typically include all non-final states:
  `:available`, `:scheduled`, `:executing`, and `:retryable` (or use the `:active` state group).

  Missing states means duplicate jobs could be enqueued when existing jobs are
  in the missing state.

  ## Examples

  Bad - only checks available state:
      unique: [fields: [:args], states: [:available]]

  Good - includes all non-final states or uses :active:
      unique: [fields: [:args], states: :active]
      unique: [fields: [:args], states: [:available, :scheduled, :executing, :retryable]]

  ## References

  - [Oban Unique Jobs Documentation](https://hexdocs.pm/oban/Oban.Worker.html#module-unique-jobs)
  """

  use ObanDoctor.Check, category: :worker

  @doc_url "https://hexdocs.pm/oban/Oban.Worker.html#module-unique-jobs"

  @recommended_states [:available, :scheduled, :executing, :retryable]

  # State groups defined by Oban
  @state_groups %{
    all: [:available, :cancelled, :completed, :discarded, :executing, :retryable, :scheduled],
    active: [:available, :executing, :retryable, :scheduled],
    executing: [:executing],
    final: [:cancelled, :completed, :discarded],
    historical: [:cancelled, :completed, :discarded],
    scheduled: [:available, :retryable, :scheduled]
  }

  @unsafe_groups [:all, :final, :historical]

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
    states = Keyword.get(unique, :states, [])

    # Don't flag if they're using an unsafe group (caught by StateGroupUsage)
    if uses_unsafe_group?(states) do
      false
    else
      expanded_states = expand_states(states)
      missing = @recommended_states -- expanded_states
      not Enum.empty?(missing)
    end
  end

  defp uses_unsafe_group?(group) when is_atom(group), do: group in @unsafe_groups
  defp uses_unsafe_group?([group]) when is_atom(group), do: group in @unsafe_groups
  defp uses_unsafe_group?(states) when is_list(states), do: Enum.any?(states, &(&1 in @unsafe_groups))
  defp uses_unsafe_group?(_), do: false

  defp expand_states(group) when is_atom(group) do
    Map.get(@state_groups, group, [group])
  end

  defp expand_states(states) when is_list(states) do
    Enum.flat_map(states, fn state ->
      case Map.get(@state_groups, state) do
        nil -> [state]
        group_states -> group_states
      end
    end)
    |> Enum.uniq()
  end

  defp expand_states(_), do: []

  defp build_issue(worker) do
    states = Keyword.get(worker.unique, :states, [])
    missing = @recommended_states -- expand_states(states)

    Issue.new(
      check: __MODULE__,
      severity: default_severity(),
      message:
        "Worker #{inspect(worker.module)} unique config missing states: #{inspect(missing)}. See #{@doc_url}",
      file: worker.file,
      line: worker.line,
      meta: %{
        worker: worker.module,
        configured_states: states,
        missing_states: missing,
        doc_url: @doc_url
      }
    )
  end
end
