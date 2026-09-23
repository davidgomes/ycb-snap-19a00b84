defmodule FreeObanUi.Jobs do
  @moduledoc """
  Reads and updates rows in Oban's `oban_jobs` table.
  """

  import Ecto.Query

  alias FreeObanUi.Repo
  alias FreeObanUi.Workers.PingWorker
  alias Oban.Job

  @states ~w(available scheduled executing retryable completed discarded cancelled)
  @page_size 25

  def states, do: @states
  def page_size, do: @page_size

  @doc """
  Lists jobs matching the given query params.

  Accepted params are `"state"`, `"queue"`, `"worker"`, and `"page"`.
  """
  def list_jobs(params \\ %{}) do
    page = page_number(params["page"])
    filters = filters(params)

    jobs =
      Job
      |> apply_filters(filters)
      |> order_by([j], desc: j.id)
      |> limit(^@page_size)
      |> offset(^((page - 1) * @page_size))
      |> Repo.all()

    total =
      Job
      |> apply_filters(filters)
      |> Repo.aggregate(:count)

    counts =
      Job
      |> apply_filters(%{filters | state: nil})
      |> group_by([j], j.state)
      |> select([j], {j.state, count(j.id)})
      |> Repo.all()
      |> Map.new()

    %{
      jobs: jobs,
      page: page,
      page_size: @page_size,
      total: total,
      total_pages: max(ceil_div(total, @page_size), 1),
      counts: counts,
      filters: filters
    }
  end

  def get_job(id) when is_integer(id), do: Repo.get(Job, id)

  def get_job(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> get_job(int)
      _ -> nil
    end
  end

  def cancel_job(%Job{id: id}) do
    :ok = Oban.cancel_job(id)
    {:ok, get_job(id)}
  end

  def retry_job(%Job{id: id}) do
    :ok = Oban.retry_job(id)
    {:ok, get_job(id)}
  end

  def delete_job(%Job{} = job), do: Repo.delete(job)

  def enqueue_ping(message) when is_binary(message) do
    message = if String.trim(message) == "", do: "ping", else: String.trim(message)

    %{message: message}
    |> PingWorker.new()
    |> Oban.insert()
  end

  defp filters(params) do
    %{
      state: present(params["state"]),
      queue: present(params["queue"]),
      worker: present(params["worker"])
    }
  end

  defp apply_filters(query, %{state: state, queue: queue, worker: worker}) do
    query
    |> filter_state(state)
    |> filter_ilike(:queue, queue)
    |> filter_ilike(:worker, worker)
  end

  defp filter_state(query, nil), do: query
  defp filter_state(query, state) when state in @states, do: where(query, [j], j.state == ^state)
  defp filter_state(query, _), do: query

  defp filter_ilike(query, _field, nil), do: query

  defp filter_ilike(query, field, value) do
    like = "%#{escape_like(value)}%"
    where(query, [j], ilike(field(j, ^field), ^like))
  end

  defp escape_like(value) do
    value
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
  end

  defp present(nil), do: nil
  defp present(""), do: nil
  defp present(value) when is_binary(value), do: value
  defp present(_), do: nil

  defp page_number(page) when is_integer(page) and page > 0, do: page

  defp page_number(page) when is_binary(page) do
    case Integer.parse(page) do
      {n, _} when n > 0 -> n
      _ -> 1
    end
  end

  defp page_number(_), do: 1

  defp ceil_div(_total, 0), do: 1
  defp ceil_div(total, size), do: div(total + size - 1, size)
end
