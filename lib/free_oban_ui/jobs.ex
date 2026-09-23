defmodule FreeObanUi.Jobs do
  @moduledoc """
  Inspects and manages the jobs of the application's Oban instance.

  Queries go through `Oban.Repo` so they honor the repo, prefix and logging
  options of the running Oban configuration.
  """

  import Ecto.Query, warn: false

  alias Oban.Job

  @states ~w(executing available scheduled retryable cancelled discarded completed)

  @default_limit 50

  @doc """
  Returns all job states, ordered as they are presented in the UI.
  """
  def states, do: @states

  @doc """
  Returns jobs ordered from newest to oldest.

  ## Options

    * `:state` - only return jobs in the given state. Returns jobs in any state when `nil`.
    * `:limit` - the maximum number of jobs to return. Defaults to #{@default_limit}.
  """
  def list_jobs(opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)

    query =
      Job
      |> filter_state(opts[:state])
      |> order_by(desc: :id)
      |> limit(^limit)

    Oban.Repo.all(conf(), query)
  end

  @doc """
  Returns a map of every job state to the number of jobs in that state.
  """
  def count_jobs_by_state do
    query =
      Job
      |> group_by([j], j.state)
      |> select([j], {j.state, count(j.id)})

    counts = conf() |> Oban.Repo.all(query) |> Map.new()

    Map.new(@states, &{&1, Map.get(counts, &1, 0)})
  end

  @doc """
  Gets a single job, returning `nil` if it does not exist.
  """
  def get_job(id), do: Oban.Repo.get(conf(), Job, id)

  @doc """
  Gets a single job.

  Raises `Ecto.NoResultsError` if the job does not exist.
  """
  def get_job!(id), do: Oban.Repo.get!(conf(), Job, id)

  @doc """
  Makes a job available for immediate execution. See `Oban.retry_job/2`.
  """
  def retry_job(%Job{} = job), do: Oban.retry_job(job)

  @doc """
  Cancels a job, killing it if it is executing. See `Oban.cancel_job/2`.
  """
  def cancel_job(%Job{} = job), do: Oban.cancel_job(job)

  @doc """
  Deletes a job unless it is currently executing.
  """
  def delete_job(%Job{id: id}) do
    query = where(Job, [j], j.id == ^id and j.state != "executing")

    Oban.Repo.delete_all(conf(), query)

    :ok
  end

  @doc """
  Returns whether `retry_job/1` would affect the job.
  """
  def can_retry?(%Job{state: state}), do: state not in ~w(available executing)

  @doc """
  Returns whether `cancel_job/1` would affect the job.
  """
  def can_cancel?(%Job{state: state}), do: state in ~w(executing available scheduled retryable)

  @doc """
  Returns whether `delete_job/1` would affect the job.
  """
  def can_delete?(%Job{state: state}), do: state != "executing"

  defp filter_state(query, nil), do: query
  defp filter_state(query, state), do: where(query, [j], j.state == ^state)

  defp conf, do: Oban.config()
end
