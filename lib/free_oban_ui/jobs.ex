defmodule FreeObanUi.Jobs do
  @moduledoc """
  Read and act on rows in Oban's `oban_jobs` table.
  """

  import Ecto.Query

  alias FreeObanUi.Repo
  alias Oban.Job

  @states ~w(available scheduled executing retryable completed cancelled discarded)

  def states, do: @states

  def list_jobs(filters \\ %{}) do
    Job
    |> filter_state(filters["state"])
    |> filter_queue(filters["queue"])
    |> filter_worker(filters["worker"])
    |> order_by([j], desc: j.id)
    |> limit(100)
    |> Repo.all()
  end

  def counts_by_state do
    Job
    |> group_by([j], j.state)
    |> select([j], {j.state, count(j.id)})
    |> Repo.all()
    |> Map.new()
  end

  def get_job!(id), do: Repo.get!(Job, id)

  def cancel_job(%Job{} = job), do: Oban.cancel_job(job)

  def retry_job(%Job{} = job), do: Oban.retry_job(job)

  defp filter_state(query, state) when state in @states do
    where(query, [j], j.state == ^state)
  end

  defp filter_state(query, _), do: query

  defp filter_queue(query, queue) when is_binary(queue) and queue != "" do
    where(query, [j], j.queue == ^queue)
  end

  defp filter_queue(query, _), do: query

  defp filter_worker(query, worker) when is_binary(worker) and worker != "" do
    like = "%#{worker}%"
    where(query, [j], ilike(j.worker, ^like))
  end

  defp filter_worker(query, _), do: query
end
