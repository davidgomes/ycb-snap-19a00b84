defmodule ObanDoctor.StateGroups do
  @moduledoc """
  Named unique state groups accepted by Oban.

  `unique: [states: ...]` takes either one of these group names or a list of
  individual job states. `:all`, `:incomplete`, and `:successful` are not job
  states, so they are invalid inside a state list. `:scheduled` is both a
  named group and a job state: it is the group only when passed as an atom.

    * `:all` — every job state
    * `:incomplete` — jobs that have not finished processing
    * `:scheduled` — only `:scheduled` jobs (useful for debouncing)
    * `:successful` — jobs that are not `:cancelled` or `:discarded` (the default)

  The state lists mirror `Oban.Job.unique_states/1`.

  See the [Unique Jobs guide](https://oban.hexdocs.pm/unique_jobs.html)
  and [`Oban.Job.unique_states/1`](https://oban.hexdocs.pm/Oban.Job.html#unique_states/1).
  """

  @unique_jobs_doc "https://oban.hexdocs.pm/unique_jobs.html"
  @unique_states_doc "https://oban.hexdocs.pm/Oban.Job.html#unique_states/1"

  @names [:all, :incomplete, :scheduled, :successful]

  # `:scheduled` is both a named group and a real job state. Inside a state
  # list it is the job state, so only these names are invalid list elements.
  @group_only [:all, :incomplete, :successful]

  # Order matches Oban.Job.states/0 and Oban.Job.unique_states/1.
  @states %{
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
  Returns the named unique state groups, in documentation order.
  """
  def names, do: @names

  @doc """
  Returns the Unique Jobs guide URL.
  """
  def doc_url, do: @unique_jobs_doc

  @doc """
  Returns the `Oban.Job.unique_states/1` documentation URL.
  """
  def unique_states_doc_url, do: @unique_states_doc

  @doc """
  Returns whether `name` is a named unique state group.
  """
  def group?(name) when is_atom(name), do: name in @names
  def group?(_), do: false

  @doc """
  Returns the job states expanded from a named group.

  Raises if `name` is not a named group.
  """
  def states(name) when name in @names, do: Map.fetch!(@states, name)

  @doc """
  Returns group-only atoms embedded in a state list.

  Named groups must be passed as an atom (`states: :incomplete`), not as a
  list element (`states: [:incomplete]`). `:scheduled` is also a job state, so
  it is allowed in a list and is only a group when passed as an atom.
  """
  def groups_in_list(states) when is_list(states) do
    Enum.filter(states, &(&1 in @group_only))
  end

  def groups_in_list(_), do: []
end
