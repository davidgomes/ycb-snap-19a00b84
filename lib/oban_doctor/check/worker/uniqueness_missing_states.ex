defmodule ObanDoctor.Check.Worker.UniquenessMissingStates do
  @moduledoc """
  Checks for workers with unique configuration using explicit states that miss recommended ones.

  When using explicit state lists (not named groups), you should typically include all
  non-final states: `:available`, `:scheduled`, `:executing`, and `:retryable`.

  Missing `:retryable` is a common issue. When a job fails and enters the retryable
  state (with backoff), a new job with the same unique key can be enqueued, causing
  duplicates.

  This check does not flag named state groups (`:incomplete`, `:scheduled`, `:successful`)
  as these are intentional Oban patterns. `:all` is handled by
  `ObanDoctor.Check.Worker.StateGroupUsage`.

  ## Examples

  Bad - only checks available state:
      unique: [fields: [:args], states: [:available]]

  Good - includes all non-final states:
      unique: [fields: [:args], states: [:available, :scheduled, :executing, :retryable]]

  Good - use the `:incomplete` named group:
      unique: [fields: [:args], states: :incomplete]

  See [Oban unique jobs](https://hexdocs.pm/oban/unique_jobs.html).
  """

  use ObanDoctor.Check, category: :worker

  @recommended_states [:available, :scheduled, :executing, :retryable]

  # Named state groups that are valid Oban patterns
  @valid_named_groups [:all, :incomplete, :scheduled, :successful]

  @impl true
  def id, do: :uniqueness_missing_states

  @impl true
  def description do
    "Detects workers with explicit unique states missing recommended ones"
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

    # Don't flag named state groups - they're valid Oban patterns
    # :all is caught by StateGroupUsage check
    # :incomplete, :scheduled, :successful are intentional
    if uses_named_group?(states) do
      false
    else
      state_list = normalize_states(states)
      missing = @recommended_states -- state_list
      not Enum.empty?(missing)
    end
  end

  # Named groups are only valid as atoms or single-element lists
  # e.g., states: :incomplete or states: [:incomplete]
  # A list like [:available, :scheduled, :executing] is NOT using a named group,
  # even though :scheduled is both a state name and a named group name
  defp uses_named_group?(states) when is_atom(states), do: states in @valid_named_groups
  defp uses_named_group?([state]) when is_atom(state), do: state in @valid_named_groups
  defp uses_named_group?(_), do: false

  defp normalize_states(states) when is_list(states), do: states
  defp normalize_states(_), do: []

  defp build_issue(worker) do
    states = Keyword.get(worker.unique, :states, [])
    missing = @recommended_states -- normalize_states(states)

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
        missing_states: missing
      }
    )
  end
end
