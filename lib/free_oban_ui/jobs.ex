defmodule FreeObanUi.Jobs do
  @moduledoc """
  Functions for listing and managing Oban jobs, powering the jobs dashboard.
  """

  import Ecto.Query, warn: false

  alias FreeObanUi.Repo
  alias Oban.Job

  @page_size 20

  @doc "The number of jobs shown per dashboard page."
  def page_size, do: @page_size

  @doc """
  Every possible job state, ordered roughly by how interesting it is to an
  operator watching the dashboard.
  """
  def states, do: ~w(executing available scheduled retryable completed cancelled discarded)

  @doc "The distinct queue names that currently have jobs, in alphabetical order."
  def queues do
    Job
    |> select([j], j.queue)
    |> distinct(true)
    |> order_by([j], asc: j.queue)
    |> Repo.all()
  end

  @doc """
  Lists jobs matching the given filters, most recently inserted first.

  ## Filters

    * `:state` - only return jobs in this state, or `"all"`/`nil` for every state
    * `:queue` - only return jobs in this queue, or `"all"`/`nil` for every queue

  ## Options

    * `:page` - the 1-indexed page of results to return, defaults to `1`
  """
  def list_jobs(filters \\ %{}, opts \\ []) do
    page = Keyword.get(opts, :page, 1)

    filters
    |> base_query()
    |> order_by(desc: :id)
    |> limit(^@page_size)
    |> offset(^((page - 1) * @page_size))
    |> Repo.all()
  end

  @doc "Counts the jobs matching the given filters. See `list_jobs/2` for filter options."
  def count_jobs(filters \\ %{}) do
    filters
    |> base_query()
    |> Repo.aggregate(:count)
  end

  defp base_query(filters) do
    Job
    |> filter_by_state(Map.get(filters, :state))
    |> filter_by_queue(Map.get(filters, :queue))
  end

  defp filter_by_state(query, state) when state in [nil, "all"], do: query
  defp filter_by_state(query, state), do: where(query, [j], j.state == ^state)

  defp filter_by_queue(query, queue) when queue in [nil, "all"], do: query
  defp filter_by_queue(query, queue), do: where(query, [j], j.queue == ^queue)

  @doc """
  Cancels a job, preventing it from running (or killing it if it's currently
  executing). Delegates to `Oban.cancel_job/1`.
  """
  defdelegate cancel_job(job_or_id), to: Oban

  @doc """
  Marks a job as immediately available for execution again. Delegates to
  `Oban.retry_job/1`.
  """
  defdelegate retry_job(job_or_id), to: Oban
end
