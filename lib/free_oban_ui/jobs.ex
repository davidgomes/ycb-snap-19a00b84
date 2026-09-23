defmodule FreeObanUi.Jobs do
  @moduledoc """
  Queries and actions for inspecting and managing Oban jobs.
  """

  import Ecto.Query

  alias FreeObanUi.Repo
  alias Oban.Job

  @states ~w(available scheduled executing retryable completed discarded cancelled)

  @doc "All Oban job states, in lifecycle order."
  def states, do: @states

  @doc """
  Lists jobs, newest first.

  ## Options

    * `:state` - only return jobs in this state
    * `:limit` - maximum number of jobs to return (default `50`)
  """
  def list_jobs(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    Job
    |> filter_state(Keyword.get(opts, :state))
    |> order_by(desc: :id)
    |> limit(^limit)
    |> Repo.all()
  end

  defp filter_state(query, state) when state in @states, do: where(query, state: ^state)
  defp filter_state(query, _state), do: query

  @doc "Returns a map of every state to the number of jobs in that state."
  def count_by_state do
    counts =
      Job
      |> group_by([j], j.state)
      |> select([j], {j.state, count(j.id)})
      |> Repo.all()
      |> Map.new()

    Map.new(@states, &{&1, Map.get(counts, &1, 0)})
  end

  def get_job(id), do: Repo.get(Job, id)

  def retryable?(%Job{state: state}), do: state not in ~w(available executing)
  def cancellable?(%Job{state: state}), do: state not in ~w(completed discarded cancelled)
  def deletable?(%Job{state: state}), do: state != "executing"

  def retry_job(%Job{} = job), do: Oban.retry_job(job)

  def cancel_job(%Job{} = job), do: Oban.cancel_job(job)

  def delete_job(%Job{} = job) do
    case Repo.delete(job) do
      {:ok, _job} -> :ok
      error -> error
    end
  end
end
