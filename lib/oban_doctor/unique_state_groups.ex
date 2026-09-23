defmodule ObanDoctor.UniqueStateGroups do
  @moduledoc """
  Named unique state groups accepted by Oban's `:states` option.

  Oban expands these atoms with `Oban.Job.unique_states/1` instead of treating
  them as individual job states. The groups below match that function:

    * `:all` — every job state, including `:completed`, `:cancelled`, and `:discarded`
    * `:incomplete` — jobs that have not finished (`:suspended`, `:available`,
      `:scheduled`, `:executing`, `:retryable`)
    * `:scheduled` — only `:scheduled` (used to debounce scheduled jobs)
    * `:successful` — in-progress jobs plus `:completed` (Oban's default). Omits
      `:cancelled` and `:discarded`

  See [`Oban.Job.unique_states/1`](https://hexdocs.pm/oban/Oban.Job.html#unique_states/1)
  and the [Unique Jobs guide](https://hexdocs.pm/oban/unique_jobs.html).
  """

  @doc_url "https://hexdocs.pm/oban/Oban.Job.html#unique_states/1"
  @guide_url "https://hexdocs.pm/oban/unique_jobs.html"

  # Mirrors Oban.Job.unique_states/1. `:suspended` is included, matching current Oban.
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

  @group_names [:all, :incomplete, :scheduled, :successful]

  @doc """
  Hexdocs page for `Oban.Job.unique_states/1`.
  """
  def doc_url, do: @doc_url

  @doc """
  Hexdocs guide for Oban unique jobs.
  """
  def guide_url, do: @guide_url

  @doc """
  Named groups Oban accepts for `unique: [states: group]`.
  """
  def groups, do: @group_names

  @doc """
  Returns whether `value` is a named state group.
  """
  def group?(value) when is_atom(value), do: Map.has_key?(@groups, value)
  def group?(_value), do: false

  @doc """
  Expands a `:states` value into concrete job states.

  A named group expands to the states Oban checks for that group. A list is
  expanded element-wise, so `[:available, :all]` includes every state in `:all`.
  `:scheduled` is both a concrete state and a group; expanding it yields
  `[:scheduled]` either way. Unknown values are left unchanged. Anything else
  expands to an empty list.
  """
  def expand(group) when is_atom(group) do
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

  def expand(_states), do: []

  @doc """
  Returns named groups referenced by a `:states` value.

  `states: :incomplete` references `[:incomplete]`. A list references each group
  atom it contains, which Oban itself rejects but workers sometimes write.
  """
  def referenced_groups(group) when is_atom(group) do
    if group?(group), do: [group], else: []
  end

  def referenced_groups(states) when is_list(states) do
    Enum.filter(states, &group?/1)
  end

  def referenced_groups(_states), do: []
end
