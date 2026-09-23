defmodule ObanDoctor.ObanStateGroups do
  @moduledoc """
  Expands Oban unique-job state groups.

  Oban accepts individual job states or these named groups in `unique: [states: ...]`:

    * `:incomplete` — `:available`, `:scheduled`, `:executing`, `:retryable`
    * `:completed` — `:completed`, `:cancelled`, `:discarded`
    * `:all` — every state

  See [Unique Jobs](https://hexdocs.pm/oban/unique_jobs.html) in the Oban docs.
  """

  @groups %{
    all: [:available, :scheduled, :executing, :retryable, :completed, :cancelled, :discarded],
    incomplete: [:available, :scheduled, :executing, :retryable],
    completed: [:completed, :cancelled, :discarded]
  }

  @doc """
  Returns the concrete states for an atom or list of states and named groups.
  """
  def expand(states) when is_atom(states), do: expand([states])

  def expand(states) when is_list(states) do
    states
    |> Enum.flat_map(fn
      group when is_map_key(@groups, group) -> Map.fetch!(@groups, group)
      state -> [state]
    end)
    |> Enum.uniq()
  end

  def expand(_), do: []

  @doc """
  Named groups present in `states` (`:all`, `:incomplete`, or `:completed`).
  """
  def named_groups(states) when is_atom(states), do: named_groups([states])

  def named_groups(states) when is_list(states) do
    Enum.filter(states, &is_map_key(@groups, &1))
  end

  def named_groups(_), do: []

  @doc """
  Whether `states` uses the `:all` or `:completed` named groups.

  Both include terminal states, so a matching job cannot be inserted again
  while that row exists. See [Unique Jobs](https://hexdocs.pm/oban/unique_jobs.html).
  """
  def terminal_group?(states) do
    states
    |> named_groups()
    |> Enum.any?(&(&1 in [:all, :completed]))
  end
end
