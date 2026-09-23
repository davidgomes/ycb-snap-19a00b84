defmodule FreeObanUi.Jobs do
  @moduledoc """
  Queries and actions for inspecting Oban jobs.
  """

  import Ecto.Query, warn: false

  alias FreeObanUi.Repo
  alias Oban.Job

  @states ~w(available scheduled executing retryable completed discarded cancelled)
  @default_limit 50

  @doc """
  Returns every possible job state, in lifecycle order.
  """
  def states, do: @states

  @doc """
  Lists jobs, most recently inserted first.

  ## Options

    * `:state` - only return jobs in the given state
    * `:queue` - only return jobs in the given queue
    * `:limit` - maximum number of jobs to return (defaults to #{@default_limit})
  """
  def list_jobs(opts \\ []) do
    Job
    |> filter_state(opts[:state])
    |> filter_queue(opts[:queue])
    |> order_by(desc: :id)
    |> limit(^Keyword.get(opts, :limit, @default_limit))
    |> Repo.all()
  end

  @doc """
  Returns a map of job counts keyed by state, including states with no jobs.
  """
  def count_by_state do
    counts =
      Job
      |> group_by(:state)
      |> select([j], {j.state, count(j.id)})
      |> Repo.all()
      |> Map.new()

    Map.new(@states, &{&1, Map.get(counts, &1, 0)})
  end

  @doc """
  Returns the distinct queue names that have jobs, sorted alphabetically.
  """
  def list_queues do
    Job
    |> distinct(true)
    |> select([j], j.queue)
    |> order_by(:queue)
    |> Repo.all()
  end

  @doc """
  Gets a single job by id, returning `nil` when it doesn't exist.
  """
  def get_job(id), do: Repo.get(Job, id)

  @doc """
  Makes a job available to run again immediately.
  """
  def retry_job(%Job{} = job), do: Oban.retry_job(job)

  @doc """
  Cancels a job that hasn't completed yet.
  """
  def cancel_job(%Job{} = job), do: Oban.cancel_job(job)

  @doc """
  Permanently deletes a job. Executing jobs are left untouched.
  """
  def delete_job(%Job{} = job), do: Oban.delete_job(job)

  defp filter_state(query, state) when state in @states, do: where(query, state: ^state)
  defp filter_state(query, _state), do: query

  defp filter_queue(query, queue) when is_binary(queue) and queue != "",
    do: where(query, queue: ^queue)

  defp filter_queue(query, _queue), do: query
end
