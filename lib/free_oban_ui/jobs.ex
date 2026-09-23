defmodule FreeObanUi.Jobs do
  @moduledoc """
  Queries and actions for inspecting Oban jobs.
  """

  import Ecto.Query

  alias FreeObanUi.Repo
  alias Oban.Job

  @states ~w(available scheduled executing retryable completed discarded cancelled)
  @default_limit 50

  def states, do: @states

  @doc """
  Lists jobs, newest first.

  ## Options

    * `:state` - only jobs in this state
    * `:queue` - only jobs in this queue
    * `:search` - case-insensitive substring match on the worker name
    * `:limit` - maximum number of jobs returned (defaults to #{@default_limit})
  """
  def list_jobs(opts \\ []) do
    Job
    |> filter_state(opts[:state])
    |> filter_queue(opts[:queue])
    |> filter_search(opts[:search])
    |> order_by(desc: :id)
    |> limit(^Keyword.get(opts, :limit, @default_limit))
    |> Repo.all()
  end

  @doc """
  Returns a map of every job state to the number of jobs in it.

  Accepts the `:queue` and `:search` options of `list_jobs/1`.
  """
  def count_by_state(opts \\ []) do
    counts =
      Job
      |> filter_queue(opts[:queue])
      |> filter_search(opts[:search])
      |> group_by([j], j.state)
      |> select([j], {j.state, count(j.id)})
      |> Repo.all()
      |> Map.new()

    Map.new(@states, &{&1, Map.get(counts, &1, 0)})
  end

  def list_queues do
    Job
    |> distinct(true)
    |> order_by(:queue)
    |> select([j], j.queue)
    |> Repo.all()
  end

  def get_job(id), do: Repo.get(Job, id)

  def retryable?(%Job{state: state}), do: state in ~w(completed retryable discarded cancelled)

  def cancellable?(%Job{state: state}), do: state in ~w(available scheduled executing retryable)

  def deletable?(%Job{state: state}), do: state != "executing"

  def retry_job(%Job{id: id}), do: Oban.retry_job(id)

  def cancel_job(%Job{id: id}), do: Oban.cancel_job(id)

  def delete_job(%Job{id: id}) do
    Job
    |> where(id: ^id)
    |> Repo.delete_all()

    :ok
  end

  defp filter_state(query, state) when state in @states, do: where(query, state: ^state)
  defp filter_state(query, _state), do: query

  defp filter_queue(query, queue) when is_binary(queue) and queue != "",
    do: where(query, queue: ^queue)

  defp filter_queue(query, _queue), do: query

  defp filter_search(query, search) when is_binary(search) do
    case String.trim(search) do
      "" -> query
      term -> where(query, [j], ilike(j.worker, ^"%#{escape_like(term)}%"))
    end
  end

  defp filter_search(query, _search), do: query

  defp escape_like(term), do: String.replace(term, ["\\", "%", "_"], &"\\#{&1}")
end
