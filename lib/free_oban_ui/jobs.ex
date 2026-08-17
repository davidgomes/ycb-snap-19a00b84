defmodule FreeObanUi.Jobs do
  @moduledoc """
  Read and manage `Oban.Job` records for the jobs dashboard.
  """

  import Ecto.Query, warn: false

  alias FreeObanUi.Repo
  alias Oban.Job

  @states Job.states() |> Enum.map(&Atom.to_string/1)

  @doc "Returns the list of valid job states, in the order they should be displayed."
  def states, do: @states

  @doc """
  Lists jobs, optionally filtered by `:state` and/or `:queue`.

  Accepts a map or keyword list with the following optional keys:

    * `:state` - restrict to a single state (e.g. `"executing"`)
    * `:queue` - restrict to a single queue name
    * `:limit` - maximum number of jobs to return (defaults to 50)
  """
  def list_jobs(filters \\ %{}) do
    filters = Map.new(filters)
    limit = Map.get(filters, :limit, 50)

    Job
    |> filter_by_state(Map.get(filters, :state))
    |> filter_by_queue(Map.get(filters, :queue))
    |> order_by(desc: :id)
    |> limit(^limit)
    |> Repo.all()
  end

  defp filter_by_state(query, nil), do: query
  defp filter_by_state(query, ""), do: query
  defp filter_by_state(query, state), do: where(query, [j], j.state == ^state)

  defp filter_by_queue(query, nil), do: query
  defp filter_by_queue(query, ""), do: query
  defp filter_by_queue(query, queue), do: where(query, [j], j.queue == ^queue)

  @doc "Returns the number of jobs in each state as a map of `state => count`."
  def count_by_state do
    counts =
      Job
      |> group_by([j], j.state)
      |> select([j], {j.state, count(j.id)})
      |> Repo.all()
      |> Map.new()

    Map.new(@states, &{&1, Map.get(counts, &1, 0)})
  end

  @doc "Returns the distinct list of known queue names, sorted alphabetically."
  def list_queues do
    Job
    |> distinct(true)
    |> select([j], j.queue)
    |> order_by(asc: :queue)
    |> Repo.all()
  end

  @doc "Fetches a single job by id, raising if it doesn't exist."
  def get_job!(id), do: Repo.get!(Job, id)

  @doc "Cancels a job, moving it to the `cancelled` state."
  def cancel_job(%Job{} = job), do: Oban.cancel_job(job.id)

  @doc "Retries a job, making it immediately available for execution."
  def retry_job(%Job{} = job), do: Oban.retry_job(job.id)

  @doc "Deletes a job permanently."
  def delete_job(%Job{} = job), do: Repo.delete(job)
end
