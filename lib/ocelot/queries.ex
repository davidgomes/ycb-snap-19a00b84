defmodule Ocelot.Queries do
  @moduledoc false

  import Ecto.Query

  alias Oban.{Job, Repo}

  @page_size 20

  def page_size, do: @page_size

  @doc """
  Returns a map of every job state (as a string) to its job count.
  """
  def state_counts(conf) do
    query =
      Job
      |> group_by([j], j.state)
      |> select([j], {j.state, count(j.id)})

    counts = conf |> Repo.all(query) |> Map.new()

    Map.new(Job.states(), fn state ->
      state = Atom.to_string(state)
      {state, Map.get(counts, state, 0)}
    end)
  end

  @doc """
  Returns `{jobs, total_pages}`, newest jobs first.

  Options: `:page` (1-based, default 1) and `:state` (a state string, or nil for all).
  """
  def list_jobs(conf, opts \\ []) do
    page = max(Keyword.get(opts, :page, 1), 1)
    query = filter_state(Job, Keyword.get(opts, :state))

    total = Repo.aggregate(conf, query, :count)

    jobs =
      query
      |> order_by([j], desc: j.id)
      |> limit(^@page_size)
      |> offset(^((page - 1) * @page_size))
      |> then(&Repo.all(conf, &1))

    {jobs, max(ceil(total / @page_size), 1)}
  end

  @doc """
  Returns a single job by integer id, or nil.
  """
  def get_job(conf, id) when is_integer(id) do
    Repo.get(conf, Job, id)
  end

  defp filter_state(query, nil), do: query
  defp filter_state(query, state), do: where(query, [j], j.state == ^state)
end
