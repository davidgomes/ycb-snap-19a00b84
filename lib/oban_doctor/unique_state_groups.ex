defmodule ObanDoctor.UniqueStateGroups do
  @unique_states_doc "https://hexdocs.pm/oban/Oban.Job.html#unique_states/1"
  @unique_jobs_guide "https://hexdocs.pm/oban/unique_jobs.html"

  @moduledoc """
  Oban named groups for `unique: [states: ...]`.

  Oban accepts a named group or an explicit list of job states. The groups and
  the states they expand to match `Oban.Job.unique_states/1`:

    * `:all` — every job state, including `:completed`, `:cancelled`, and `:discarded`
    * `:incomplete` — jobs that have not finished: `:suspended`, `:available`,
      `:scheduled`, `:executing`, and `:retryable`
    * `:scheduled` — only `:scheduled` (used to debounce)
    * `:successful` — jobs that are not `:cancelled` or `:discarded` (Oban's default)

  ## References

    * [Oban.Job.unique_states/1](#{@unique_states_doc})
    * [Unique Jobs](#{@unique_jobs_guide})
  """

  @incomplete [:suspended, :available, :scheduled, :executing, :retryable]
  @successful @incomplete ++ [:completed]
  @all [
    :suspended,
    :scheduled,
    :available,
    :executing,
    :retryable,
    :completed,
    :discarded,
    :cancelled
  ]

  @groups %{
    all: @all,
    incomplete: @incomplete,
    scheduled: [:scheduled],
    successful: @successful
  }

  @known_groups [:all, :incomplete, :scheduled, :successful]

  # These names are groups, not job states. Listing them inside `:states` is
  # invalid; pass the group as an atom (`states: :incomplete`). `:scheduled`
  # is both a group and a real state, so it may appear in an explicit list.
  @list_only_groups [:all, :incomplete, :successful]

  @doc """
  Canonical documentation URLs for named unique state groups.
  """
  def doc_urls do
    %{
      unique_states: @unique_states_doc,
      unique_jobs: @unique_jobs_guide
    }
  end

  @doc """
  URL for `Oban.Job.unique_states/1`.
  """
  def unique_states_doc, do: @unique_states_doc

  @doc """
  States covered by the `:incomplete` group.

  This is the set a unique constraint should include when duplicates must be
  prevented for jobs that have not finished.
  """
  def incomplete_states, do: @incomplete

  @doc """
  Known named group atoms, in definition order.
  """
  def known_groups, do: @known_groups

  @doc """
  Returns true when `states` is one of the named groups.
  """
  def known?(group) when is_atom(group) and not is_nil(group), do: Map.has_key?(@groups, group)
  def known?(_), do: false

  @doc """
  Returns true when `states` is a named group, or the explicit `[:scheduled]`
  list Oban treats as that group.
  """
  def intentional?(states) when is_atom(states), do: known?(states)
  def intentional?([:scheduled]), do: true
  def intentional?(_), do: false

  @doc """
  Returns true when `:states` is the `:all` group, including `[:all]` and
  lists that mix `:all` with other states.
  """
  def all_group?(:all), do: true
  def all_group?([:all]), do: true
  def all_group?(states) when is_list(states), do: :all in states
  def all_group?(_), do: false

  @doc """
  Returns true when a state list contains a named group that is not itself a
  job state.
  """
  def embedded_group?(states) when is_list(states) do
    Enum.any?(states, &(&1 in @list_only_groups))
  end

  def embedded_group?(_), do: false

  @doc """
  Expands a named group or a list of states into concrete job states.

  Named groups inside a list are expanded. Unknown atoms are left as-is.
  Unknown group atoms (not in a list) expand to an empty list.
  """
  def expand(group) when is_atom(group) and not is_nil(group) do
    Map.get(@groups, group, [])
  end

  def expand(states) when is_list(states) do
    states
    |> Enum.flat_map(fn
      group when is_atom(group) ->
        case Map.fetch(@groups, group) do
          {:ok, expanded} -> expanded
          :error -> [group]
        end

      other ->
        [other]
    end)
    |> Enum.uniq()
  end

  def expand(_), do: []
end
