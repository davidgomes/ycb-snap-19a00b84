defmodule FreeObanUi.Jobs do
  @moduledoc """
  Context module for querying and interacting with Oban Jobs and Queues.
  """

  import Ecto.Query, warn: false
  alias FreeObanUi.Repo
  alias Oban.Job

  @doc """
  Returns a list of all distinct queues found in the oban_jobs table or currently configured.
  """
  def list_queues do
    configured_queues =
      case Application.get_env(:free_oban_ui, Oban)[:queues] do
        queues when is_list(queues) -> Enum.map(queues, fn {q, _} -> to_string(q) end)
        _ -> []
      end

    db_queues =
      Job
      |> select([j], j.queue)
      |> distinct(true)
      |> Repo.all()

    Enum.uniq(configured_queues ++ db_queues) |> Enum.sort()
  end

  @doc """
  Returns count of jobs grouped by state.
  """
  def count_jobs_by_state(params \\ %{}) do
    query =
      Job
      |> select([j], {j.state, count(j.id)})
      |> group_by([j], j.state)

    query =
      if queue = params["queue"] || params[:queue] do
        if queue != "" and queue != "all" do
          where(query, [j], j.queue == ^queue)
        else
          query
        end
      else
        query
      end

    counts = Repo.all(query) |> Map.new()

    %{
      "all" => Enum.reduce(counts, 0, fn {_k, v}, acc -> acc + v end),
      "available" => Map.get(counts, "available", 0),
      "executing" => Map.get(counts, "executing", 0),
      "scheduled" => Map.get(counts, "scheduled", 0),
      "retryable" => Map.get(counts, "retryable", 0),
      "completed" => Map.get(counts, "completed", 0),
      "cancelled" => Map.get(counts, "cancelled", 0),
      "discarded" => Map.get(counts, "discarded", 0)
    }
  end

  @doc """
  Lists jobs matching filters.
  """
  def list_jobs(params \\ %{}) do
    Job
    |> filter_jobs(params)
    |> paginate_jobs(params)
    |> Repo.all()
  end

  @doc """
  Counts total jobs matching filters (for pagination).
  """
  def count_jobs(params \\ %{}) do
    Job
    |> filter_jobs(params)
    |> Repo.aggregate(:count, :id)
  end

  defp filter_jobs(query, params) do
    Enum.reduce(params, query, fn
      {"state", state}, query when is_binary(state) and state != "" and state != "all" ->
        where(query, [j], j.state == ^state)

      {"queue", queue}, query when is_binary(queue) and queue != "" and queue != "all" ->
        where(query, [j], j.queue == ^queue)

      {"worker", worker}, query when is_binary(worker) and worker != "" ->
        where(query, [j], ilike(j.worker, ^"%#{worker}%"))

      {"search", search}, query when is_binary(search) and search != "" ->
        where(query, [j], ilike(j.worker, ^"%#{search}%") or ilike(j.queue, ^"%#{search}%"))

      _, query ->
        query
    end)
  end

  defp paginate_jobs(query, params) do
    page =
      case params["page"] || params[:page] do
        p when is_binary(p) -> String.to_integer(p)
        p when is_integer(p) and p > 0 -> p
        _ -> 1
      end

    page_size =
      case params["page_size"] || params[:page_size] do
        ps when is_binary(ps) -> String.to_integer(ps)
        ps when is_integer(ps) and ps > 0 -> ps
        _ -> 20
      end

    sort_by = params["sort_by"] || params[:sort_by] || "id"
    sort_order = params["sort_order"] || params[:sort_order] || "desc"

    order_expr =
      case {sort_by, sort_order} do
        {"id", "asc"} -> [asc: :id]
        {"id", "desc"} -> [desc: :id]
        {"inserted_at", "asc"} -> [asc: :inserted_at]
        {"inserted_at", "desc"} -> [desc: :inserted_at]
        {"scheduled_at", "asc"} -> [asc: :scheduled_at]
        {"scheduled_at", "desc"} -> [desc: :scheduled_at]
        {"attempt", "asc"} -> [asc: :attempt]
        {"attempt", "desc"} -> [desc: :attempt]
        _ -> [desc: :id]
      end

    query
    |> order_by(^order_expr)
    |> limit(^page_size)
    |> offset(^((page - 1) * page_size))
  end

  @doc """
  Gets a single job by id.
  """
  def get_job(id) do
    Repo.get(Job, id)
  end

  @doc """
  Gets a single job by id, raising if not found.
  """
  def get_job!(id) do
    Repo.get!(Job, id)
  end

  @doc """
  Retries a job.
  """
  def retry_job(job_or_id) do
    Oban.retry_job(job_or_id)
  end

  @doc """
  Cancels a job.
  """
  def cancel_job(job_or_id) do
    Oban.cancel_job(job_or_id)
  end

  @doc """
  Deletes a job.
  """
  def delete_job(%Job{} = job) do
    Repo.delete(job)
  end

  def delete_job(job_id) when is_integer(job_id) do
    case get_job(job_id) do
      nil -> {:error, :not_found}
      job -> Repo.delete(job)
    end
  end

  @doc """
  Retries all matching jobs.
  """
  def retry_all(params \\ %{}) do
    query = filter_jobs(Job, params)
    Oban.retry_all_jobs(query)
  end

  @doc """
  Cancels all matching jobs.
  """
  def cancel_all(params \\ %{}) do
    query = filter_jobs(Job, params)
    Oban.cancel_all_jobs(query)
  end
end
