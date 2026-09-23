defmodule FreeObanUi.Jobs do
  @moduledoc """
  Queries and actions on Oban jobs for the jobs UI.
  """

  import Ecto.Query, warn: false

  alias FreeObanUi.Repo
  alias Oban.Job

  @states Enum.map(Job.states(), &Atom.to_string/1)

  # Mirror the state guards used by Oban's engines for these operations.
  @cancellable_states ~w(scheduled available executing retryable)
  @retryable_states ~w(scheduled retryable completed discarded cancelled)
  @deletable_states @states -- ["executing"]

  @default_limit 50

  @doc """
  Returns all job states, in lifecycle order.
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
  defp filter_state(query, state), do: where(query, state: ^state)

  @doc """
  Returns a map of every job state to the number of jobs in that state.
  """
  def count_by_state do
    counts =
      Job
      |> group_by([j], j.state)
      |> select([j], {j.state, count(j.id)})
      |> Repo.all()
      |> Map.new()

    Map.new(@states, &{&1, Map.get(counts, &1, 0)})
  end

  @doc """
  Gets a single job, returning `nil` if it does not exist.
  """
  def get_job(id), do: Repo.get(Job, id)

  def cancellable?(%Job{state: state}), do: state in @cancellable_states
  def retryable?(%Job{state: state}), do: state in @retryable_states
  def deletable?(%Job{state: state}), do: state in @deletable_states

  @doc """
  Cancels a job, stopping it if it is currently executing.
  """
  def cancel_job(%Job{} = job), do: Oban.cancel_job(job)

  @doc """
  Makes a job available for immediate execution.
  """
  def retry_job(%Job{} = job), do: Oban.retry_job(job)

  @doc """
  Permanently deletes a job.
  """
  def delete_job(%Job{} = job), do: Repo.delete(job)
end
