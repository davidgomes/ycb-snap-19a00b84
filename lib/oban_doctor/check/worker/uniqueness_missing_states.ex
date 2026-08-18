defmodule ObanDoctor.Check.Worker.UniquenessMissingStates do
  @moduledoc """
  Checks for workers with unique configuration using explicit states that miss recommended ones.

  When using explicit state lists (not named groups), you should typically include all non-final states:
  `:available`, `:scheduled`, `:executing`, and `:retryable`.

  Missing states means duplicate jobs could be enqueued when existing jobs are
  in the missing state (e.g. while retrying).

  This check does not flag named state groups (`:incomplete`, `:scheduled`, `:successful`)
  as these are intentional Oban patterns.

  ## Examples

  Bad - only checks available state:
      unique: [fields: [:args], states: [:available]]

  Good - includes all non-final states:
      unique: [fields: [:args], states: [:available, :scheduled, :executing, :retryable]]

  Good - uses named state group:
      unique: [fields: [:args], states: :incomplete]

  ## Documentation

  See [Oban Unique Jobs](https://hexdocs.pm/oban/unique_jobs.html#states).
  """

  use ObanDoctor.Check, category: :worker

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
    states = Keyword.get(unique, :states, [])

    # Don't flag if they're using named state groups (:all is caught by StateGroupUsage check)
    if uses_named_group?(states) do
      false
    else
      state_list = normalize_states(states)
      missing = @recommended_states -- state_list
      not Enum.empty?(missing)
    end
  end

  defp uses_named_group?(:all), do: true
  defp uses_named_group?([:all]), do: true
  defp uses_named_group?(:incomplete), do: true
  defp uses_named_group?([:incomplete]), do: true
  defp uses_named_group?(:scheduled), do: true
  defp uses_named_group?([:scheduled]), do: true
  defp uses_named_group?(:successful), do: true
  defp uses_named_group?([:successful]), do: true
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
