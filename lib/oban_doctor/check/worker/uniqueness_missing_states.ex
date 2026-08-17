defmodule ObanDoctor.Check.Worker.UniquenessMissingStates do
  @moduledoc """
  Checks for workers with unique configuration that don't include all recommended states.

  When using unique constraints, you should typically include all non-final states:
  `:available`, `:scheduled`, `:executing`, and `:retryable`.

  Missing states means duplicate jobs could be enqueued when existing jobs are
  in the missing state.

  Workers using one of Oban's named state groups (`:all`, `:incomplete`, `:scheduled`,
  or `:successful`) are not flagged, since those groups are maintained by Oban and
  already cover the appropriate states. See the
  [`Oban.Job.unique_states/1`](https://hexdocs.pm/oban/Oban.Job.html#unique_states/1)
  docs and the [Unique Jobs guide](https://hexdocs.pm/oban/unique_jobs.html) for details.

  ## Examples

  Bad - only checks available state:
      unique: [fields: [:args], states: [:available]]

  Good - includes all non-final states:
      unique: [fields: [:args], states: [:available, :scheduled, :executing, :retryable]]

  Also good - uses a named state group:
      unique: [fields: [:args], states: :incomplete]
  """

  use ObanDoctor.Check, category: :worker

  @recommended_states [:available, :scheduled, :executing, :retryable]
  @named_state_groups [:all, :incomplete, :scheduled, :successful]

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

    # Don't flag named state groups (e.g. :all, that's caught by another check) -
    # they're maintained by Oban and already include the appropriate states.
    if uses_named_group?(states) do
      false
    else
      state_list = normalize_states(states)
      missing = @recommended_states -- state_list
      not Enum.empty?(missing)
    end
  end

  # Only a bare atom or single-element list is treated as a named group reference.
  # Multi-element lists are explicit state lists, where `:scheduled` may legitimately
  # appear alongside other states rather than referring to the `:scheduled` group.
  defp uses_named_group?(group) when group in @named_state_groups, do: true
  defp uses_named_group?([group]) when group in @named_state_groups, do: true
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
