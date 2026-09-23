defmodule FreeObanUi.Jobs do
  @moduledoc """
  Queries and actions for inspecting and managing Oban jobs.
  """

  import Ecto.Query, warn: false

  alias FreeObanUi.Repo
  alias Oban.Job

  @default_limit 50

  @retryable_states ~w(retryable completed discarded cancelled)
  @cancellable_states ~w(scheduled available executing retryable)

  @doc """
  Returns every job state in lifecycle order.
  """
  def states, do: Enum.map(Job.states(), &Atom.to_string/1)

  @doc """
  Returns jobs, most recently inserted first.

  ## Options

    * `:state` - only return jobs in this state
    * `:queue` - only return jobs in this queue
    * `:limit` - the maximum number of jobs to return, defaults to #{@default_limit}

  """
  def list_jobs(opts \\ []) do
    Job
    |> filter(opts)
    |> order_by(desc: :id)
    |> limit(^Keyword.get(opts, :limit, @default_limit))
    |> Repo.all()
  end

  @doc """
  Returns a map of every job state to the number of jobs in that state.

  Accepts the same `:queue` option as `list_jobs/1`.
  """
  def count_jobs_by_state(opts \\ []) do
    counts =
      Job
      |> filter(Keyword.take(opts, [:queue]))
      |> group_by([j], j.state)
      |> select([j], {j.state, count(j.id)})
      |> Repo.all()
      |> Map.new()

    Map.new(states(), &{&1, Map.get(counts, &1, 0)})
  end

  @doc """
  Returns the names of all queues that have jobs, sorted alphabetically.
  """
  def list_queues do
    Job
    |> distinct(true)
    |> select([j], j.queue)
    |> order_by(:queue)
    |> Repo.all()
  end

  @doc """
  Gets a single job, returning `nil` if it doesn't exist.
  """
  def get_job(id), do: Repo.get(Job, id)

  @doc """
  Gets a single job.

  Raises `Ecto.NoResultsError` if the job does not exist.
  """
  def get_job!(id), do: Repo.get!(Job, id)

  @doc """
  Makes a job available for immediate execution.
  """
  def retry_job(%Job{} = job), do: Oban.retry_job(job)

  @doc """
  Cancels a job, killing it if it is currently executing.
  """
  def cancel_job(%Job{} = job), do: Oban.cancel_job(job)

  @doc """
  Returns whether the job is in a state that can be retried.
  """
  def retryable?(%Job{state: state}), do: state in @retryable_states

  @doc """
  Returns whether the job is in a state that can be cancelled.
  """
  def cancellable?(%Job{state: state}), do: state in @cancellable_states

  defp filter(query, opts) do
    Enum.reduce(opts, query, fn
      {:state, state}, query when is_binary(state) -> where(query, [j], j.state == ^state)
      {:queue, queue}, query when is_binary(queue) -> where(query, [j], j.queue == ^queue)
      _other, query -> query
    end)
  end
end
