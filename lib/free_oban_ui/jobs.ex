defmodule FreeObanUi.Jobs do
  @moduledoc """
  Queries and actions for Oban jobs, backing the jobs UI.
  """

  import Ecto.Query

  alias FreeObanUi.Repo
  alias Oban.Job

  @states ~w(executing available scheduled retryable cancelled discarded completed)

  @default_limit 50

  @doc """
  Returns the job states in display order.
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
  Fetches a single job, returning `nil` when it doesn't exist.
  """
  def get_job(id), do: Repo.get(Job, id)

  @doc """
  Fetches a single job, raising when it doesn't exist.
  """
  def get_job!(id), do: Repo.get!(Job, id)

  @doc """
  Whether the job can be retried, i.e. made available to run again.
  """
  def retryable?(%Job{state: state}), do: state not in ~w(available executing)

  @doc """
  Whether the job can be cancelled.
  """
  def cancellable?(%Job{state: state}), do: state not in ~w(completed discarded cancelled)

  @doc """
  Whether the job can be deleted.
  """
  def deletable?(%Job{state: state}), do: state != "executing"

  def retry_job(%Job{} = job), do: Oban.retry_job(job)

  def cancel_job(%Job{} = job), do: Oban.cancel_job(job)

  def delete_job(%Job{id: id}) do
    Job
    |> where([j], j.id == ^id and j.state != "executing")
    |> Repo.delete_all()

    :ok
  end
end
