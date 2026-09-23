defmodule FreeObanUi.Jobs do
  @moduledoc """
  Queries and operations for inspecting and managing Oban jobs.
  """

  import Ecto.Query, warn: false

  alias Oban.Job

  @states ~w(executing available scheduled retryable cancelled discarded completed)

  @retry_states ~w(scheduled retryable cancelled discarded completed)
  @cancel_states ~w(executing available scheduled retryable)

  @doc """
  Returns all job states in display order.
  """
  def states, do: @states

  @doc """
  Returns a page of jobs, optionally filtered by state.

  Pending jobs are ordered by when they will run next, and finished or
  executing jobs by their most recent activity.

  ## Options

    * `:state` - only return jobs in the given state
    * `:limit` - the maximum number of jobs to return, defaults to `20`
    * `:offset` - the number of jobs to skip, defaults to `0`
  """
  def list_jobs(opts \\ []) do
    state = Keyword.get(opts, :state)

    Job
    |> filter_state(state)
    |> order_by(^order_for_state(state))
    |> limit(^Keyword.get(opts, :limit, 20))
    |> offset(^Keyword.get(opts, :offset, 0))
    |> repo_all()
  end

  defp filter_state(query, nil), do: query
  defp filter_state(query, state), do: where(query, [j], j.state == ^state)

  defp order_for_state(nil), do: [desc: :id]
  defp order_for_state("executing"), do: [desc: :attempted_at, desc: :id]
  defp order_for_state("completed"), do: [desc: :completed_at, desc: :id]
  defp order_for_state("cancelled"), do: [desc: :cancelled_at, desc: :id]
  defp order_for_state("discarded"), do: [desc: :discarded_at, desc: :id]
  defp order_for_state(_pending), do: [asc: :scheduled_at, asc: :id]

  @doc """
  Returns a map of every job state to the number of jobs in that state.
  """
  def count_jobs_by_state do
    counts =
      Job
      |> group_by([j], j.state)
      |> select([j], {j.state, count(j.id)})
      |> repo_all()
      |> Map.new()

    Map.new(@states, &{&1, Map.get(counts, &1, 0)})
  end

  @doc """
  Gets a single job, returning `nil` if it does not exist.
  """
  def get_job(id), do: Oban.Repo.get(Oban.config(), Job, id)

  @doc """
  Gets a single job.

  Raises `Ecto.NoResultsError` if the job does not exist.
  """
  def get_job!(id), do: Oban.Repo.get!(Oban.config(), Job, id)

  @doc """
  Returns whether the job can be retried, or run immediately if it's scheduled.
  """
  def can_retry?(%Job{state: state}), do: state in @retry_states

  @doc """
  Returns whether the job can be cancelled.
  """
  def can_cancel?(%Job{state: state}), do: state in @cancel_states

  @doc """
  Returns whether the job can be deleted. Executing jobs must be cancelled first.
  """
  def can_delete?(%Job{state: state}), do: state != "executing"

  @doc """
  Makes the job available to run immediately.
  """
  def retry_job(%Job{} = job) do
    if can_retry?(job), do: Oban.retry_job(job), else: {:error, :invalid_state}
  end

  @doc """
  Cancels the job, killing it if it's currently executing.
  """
  def cancel_job(%Job{} = job) do
    if can_cancel?(job), do: Oban.cancel_job(job), else: {:error, :invalid_state}
  end

  @doc """
  Deletes the job.
  """
  def delete_job(%Job{id: id} = job) do
    # The job may have started executing since it was loaded, so the query guards the state too.
    query = where(Job, [j], j.id == ^id and j.state != "executing")

    with true <- can_delete?(job),
         {1, _} <- Oban.Repo.delete_all(Oban.config(), query) do
      :ok
    else
      _ -> {:error, :invalid_state}
    end
  end

  defp repo_all(query), do: Oban.Repo.all(Oban.config(), query)
end
