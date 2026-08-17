defmodule ObanDoctor.ObanStates do
  @moduledoc """
  Shared definitions for Oban's named unique-state groups.

  Oban's `:unique` option accepts either a named state group (an atom) or an
  explicit list of individual job states. See the Oban documentation for the
  authoritative definitions:

    * `Oban.Job.unique_states/1` - https://hexdocs.pm/oban/Oban.Job.html#unique_states/1
    * Unique Jobs guide - https://hexdocs.pm/oban/unique_jobs.html
  """

  @named_groups %{
    all: [:scheduled, :available, :executing, :retryable, :completed, :discarded, :cancelled],
    incomplete: [:available, :scheduled, :executing, :retryable],
    scheduled: [:scheduled],
    successful: [:available, :scheduled, :executing, :retryable, :completed]
  }

  @doc """
  Returns the list of named state group atoms, e.g. `[:all, :incomplete, :scheduled, :successful]`.
  """
  def named_groups, do: Map.keys(@named_groups)

  @doc """
  Returns true if `states` refers to a named state group.

  Named groups (`:all`, `:incomplete`, `:scheduled`, `:successful`) are only
  valid as a bare atom per Oban's API. A raw state list that includes `:all`
  is also treated as a named group here, since that pattern is the dangerous
  usage flagged by `ObanDoctor.Check.Worker.StateGroupUsage`.
  """
  def named_group?(states) when is_atom(states) and not is_nil(states) do
    states in named_groups()
  end

  def named_group?(states) when is_list(states), do: :all in states
  def named_group?(_), do: false

  @doc """
  Expands a named state group into its underlying list of job states.

  Returns `nil` if `states` is not a recognized named group.
  """
  def expand(states) when is_atom(states), do: Map.get(@named_groups, states)
  def expand(_), do: nil
end
