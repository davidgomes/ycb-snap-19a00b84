defmodule Ocelot.Queries do
  @moduledoc false

  import Ecto.Query

  alias Oban.{Job, Repo}

  def queue_counts(conf) do
    query =
      Job
      |> group_by([j], j.queue)
      |> order_by([j], asc: j.queue)
      |> select([j], {j.queue, count(j.id)})

    Repo.all(conf, query)
  end

  def state_counts(conf, opts) do
    query =
      Job
      |> filter_queue(opts[:queue])
      |> group_by([j], j.state)
      |> select([j], {j.state, count(j.id)})

    conf
    |> Repo.all(query)
    |> Map.new()
  end

  @doc """
  Returns a page of jobs, newest first, along with whether a next page exists.
  """
  def list_jobs(conf, opts) do
    page = Keyword.fetch!(opts, :page)
    per_page = Keyword.fetch!(opts, :per_page)

    query =
      Job
      |> filter_state(opts[:state])
      |> filter_queue(opts[:queue])
      |> order_by([j], desc: j.id)
      |> limit(^(per_page + 1))
      |> offset(^((page - 1) * per_page))

    jobs = Repo.all(conf, query)

    {Enum.take(jobs, per_page), length(jobs) > per_page}
  end

  def get_job(conf, id), do: Repo.get(conf, Job, id)

  defp filter_state(query, nil), do: query
  defp filter_state(query, state), do: where(query, [j], j.state == ^state)

  defp filter_queue(query, nil), do: query
  defp filter_queue(query, queue), do: where(query, [j], j.queue == ^queue)
end
