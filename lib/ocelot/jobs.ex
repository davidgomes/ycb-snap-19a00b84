defmodule Ocelot.Jobs do
  @moduledoc false

  import Ecto.Query

  alias Oban.{Job, Repo}

  @doc """
  All job states, in lifecycle order.
  """
  def states, do: Enum.map(Job.states(), &Atom.to_string/1)

  @doc """
  Returns `{state, count}` for every job state, including empty ones.
  """
  def count_by_state(conf) do
    query =
      Job
      |> group_by([j], j.state)
      |> select([j], {j.state, count(j.id)})

    counts = conf |> Repo.all(query) |> Map.new()

    for state <- states(), do: {state, Map.get(counts, state, 0)}
  end

  @doc """
  Lists jobs, newest first.

  ## Options

    * `:state` - only return jobs in this state. All states when `nil`.
    * `:limit` - maximum number of jobs to return.
    * `:offset` - number of jobs to skip.
  """
  def list(conf, opts) do
    limit = Keyword.fetch!(opts, :limit)
    offset = Keyword.get(opts, :offset, 0)

    query =
      Job
      |> filter_state(Keyword.get(opts, :state))
      |> order_by(desc: :id)
      |> limit(^limit)
      |> offset(^offset)

    Repo.all(conf, query)
  end

  @doc """
  Fetches a single job by id, returning `nil` when it doesn't exist.
  """
  def get(conf, id), do: Repo.get(conf, Job, id)

  defp filter_state(query, nil), do: query
  defp filter_state(query, state), do: where(query, [j], j.state == ^state)
end
