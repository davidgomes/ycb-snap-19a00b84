defmodule ObanDoctor.UniqueStateGroups do
  @unique_states_url "https://hexdocs.pm/oban/Oban.Job.html#unique_states/1"
  @unique_jobs_url "https://hexdocs.pm/oban/unique_jobs.html"
  @upgrade_url "https://hexdocs.pm/oban/v2-20.html#update-unique-states-optional"

  @moduledoc """
  Named unique state groups accepted by Oban since v2.20.

  `unique: [states: ...]` may be a group name or an explicit list of job states.
  Group membership matches `Oban.Job.unique_states/1`.

  ## Groups

    * `:all` — every job state, including `:completed`, `:discarded`, and
      `:cancelled`
    * `:incomplete` — jobs that have not finished processing
    * `:scheduled` — only `:scheduled` jobs
    * `:successful` — jobs that are not `:cancelled` or `:discarded` (Oban's
      default)

  ## References

    * [Oban.Job.unique_states/1](#{@unique_states_url})
    * [Unique Jobs](#{@unique_jobs_url})
    * [Upgrading to v2.20 — Update Unique States](#{@upgrade_url})
  """

  # Order matches Oban.Job.unique_states/1 and Oban.Job.states/0.
  @groups %{
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

  @doc """
  Returns the documentation URL for `Oban.Job.unique_states/1`.
  """
  def unique_states_url, do: @unique_states_url

  @doc """
  Returns the documentation URL for Oban's Unique Jobs guide.
  """
  def unique_jobs_url, do: @unique_jobs_url

  @doc """
  Returns the documentation URL for the Oban v2.20 unique-state upgrade notes.
  """
  def upgrade_url, do: @upgrade_url

  @doc """
  Returns the states belonging to a named group, or `nil` when `name` is not a group.
  """
  def states(name) when is_atom(name), do: Map.get(@groups, name)

  @doc """
  Returns the group name for a `:states` option.

  A bare group atom and a single-element list of a group (`[:incomplete]`) both
  resolve to that group. Explicit state lists and unknown atoms return `nil`.
  """
  def group_name(name) when is_atom(name) do
    if Map.has_key?(@groups, name), do: name, else: nil
  end

  def group_name([name]) when is_atom(name), do: group_name(name)
  def group_name(_states), do: nil

  @doc """
  Expands a `:states` option into concrete job states.

  Named groups expand to the states in that group. Explicit lists are returned
  unchanged. Any other value expands to an empty list.
  """
  def expand(states) do
    case group_name(states) do
      nil when is_list(states) -> states
      nil -> []
      group -> Map.fetch!(@groups, group)
    end
  end
end
