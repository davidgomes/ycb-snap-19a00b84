defmodule FreeObanUi.Jobs do
  @moduledoc """
  Queries and actions for browsing and managing Oban jobs.
  """

  import Ecto.Query, warn: false

  alias FreeObanUi.Repo
  alias Oban.Job

  @states ~w(available scheduled executing retryable completed discarded cancelled)

  @default_limit 50

  @doc """
  Returns every possible Oban job state, in lifecycle order.
  """
  def states, do: @states

  @doc """
  Lists jobs, newest first.

  ## Options

    * `:state` - only return jobs in the given state
    * `:limit` - maximum number of jobs to return, defaults to #{@default_limit}
  """
  def list_jobs(opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)

    Job
    |> filter_state(Keyword.get(opts, :state))
    |> order_by(desc: :id)
    |> limit(^limit)
    |> Repo.all()
  end

  defp filter_state(query, nil), do: query
  defp filter_state(query, state) when state in @states, do: where(query, state: ^state)

  @doc """
  Returns a map of every job state to the number of jobs in that state.
  """
  def count_jobs_by_state do
    counts =
      Job
      |> group_by([j], j.state)
      |> select([j], {j.state, count(j.id)})
      |> Repo.all()
      |> Map.new()

    Map.new(@states, &{&1, Map.get(counts, &1, 0)})
  end

  @doc """
  Gets a single job, returning `nil` when it doesn't exist.
  """
  def get_job(id), do: Repo.get(Job, id)

  @doc """
  Gets a single job, raising `Ecto.NoResultsError` when it doesn't exist.
  """
  def get_job!(id), do: Repo.get!(Job, id)

  @doc """
  Makes a job available for execution again, regardless of its attempts.
  """
  def retry_job(%Job{} = job), do: Oban.retry_job(job)

  @doc """
  Cancels a job that hasn't finished yet.
  """
  def cancel_job(%Job{} = job), do: Oban.cancel_job(job)

  @doc """
  Permanently deletes a job.
  """
  def delete_job(%Job{} = job), do: Repo.delete(job)

  def retryable?(%Job{state: state}), do: state not in ~w(available executing)

  def cancellable?(%Job{state: state}), do: state not in ~w(completed discarded cancelled)

  def deletable?(%Job{state: state}), do: state != "executing"
end
