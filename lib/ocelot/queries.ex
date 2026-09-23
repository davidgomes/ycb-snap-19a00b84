defmodule Ocelot.Queries do
  @moduledoc false

  import Ecto.Query

  alias Oban.{Job, Repo}

  @page_size 20

  def page_size, do: @page_size

  @doc """
  Returns `{jobs, total_count}` for the requested page, newest jobs first.

  ## Options

    * `:state` - only return jobs in this state, all states when `nil`
    * `:page` - 1-based page number, defaults to `1`
  """
  def list_jobs(conf, opts \\ []) do
    page = max(Keyword.get(opts, :page, 1), 1)
    query = filter_state(Job, Keyword.get(opts, :state))

    total = Repo.aggregate(conf, query, :count)

    jobs =
      query
      |> order_by([j], desc: j.id)
      |> limit(@page_size)
      |> offset(^((page - 1) * @page_size))
      |> then(&Repo.all(conf, &1))

    {jobs, total}
  end

  @doc """
  Returns a map of job state to the number of jobs in that state.
  """
  def state_counts(conf) do
    query =
      Job
      |> group_by([j], j.state)
      |> select([j], {j.state, count(j.id)})

    conf
    |> Repo.all(query)
    |> Map.new()
  end

  def get_job(conf, id), do: Repo.get(conf, Job, id)

  defp filter_state(query, nil), do: query
  defp filter_state(query, state), do: where(query, [j], j.state == ^state)
end
