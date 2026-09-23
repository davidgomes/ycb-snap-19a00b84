defmodule Oban.Console.Jobs do
  import Ecto.Query

  alias Oban.Console.Repo
  alias Oban.Console.Storage
  alias Oban.Console.View.Printer
  alias Oban.Console.View.Table

  @states %{
    "1" => "available",
    "2" => "scheduled",
    "3" => "retryable",
    "4" => "executing",
    "5" => "completed",
    "6" => "discarded",
    "7" => "cancelled"
  }

  @in_progress_states ~w[available scheduled retryable executing]
  @failed_states ~w[cancelled discarded]

  def list(opts \\ []), do: Repo.all(list_query(opts))

  def show_list(opts \\ []) do
    headers = [:id, :worker, :state, :queue, :attempt, :inserted_at, :attempted_at, :scheduled_at]
    opts = if opts == [], do: Storage.get_last_jobs_opts(), else: opts

    limit = Keyword.get(opts, :limit, 20) || 20
    converted_states = convert_states(Keyword.get(opts, :states, []) || [])
    ids = ids_listed_before(opts)

    opts =
      opts
      |> Keyword.put(:ids, ids)
      |> Keyword.put(:states, converted_states)
      |> Keyword.put(:limit, limit)

    response = list(opts)

    Storage.set_last_jobs_ids(Enum.map(response, & &1.id))
    Storage.set_last_jobs_opts(opts)
    Storage.add_job_filter_history(opts)

    filters = Enum.reject(opts, fn {_, value} -> value in [nil, []] end)
    current_time = Calendar.strftime(DateTime.utc_now(), "%Y-%m-%d %H:%M:%S")

    Table.show(
      response,
      headers,
      "[#{current_time}] Rows: #{length(response)} Filters: #{inspect(filters)} Sorts: DESC attempted_at, DESC scheduled_at"
    )
  end

  def clean_storage(), do: Storage.set_last_jobs_opts([])

  def debug_jobs([_ | _] = jobs_ids), do: Enum.each(jobs_ids, &debug_jobs/1)
  def debug_jobs([]), do: :ok

  def debug_jobs(job_id) when is_integer(job_id) do
    case Repo.get_job(job_id) do
      nil ->
        ["Job", job_id, "Job not found"] |> Printer.title() |> IO.puts()

      job ->
        ["Job", job_id] |> Printer.title() |> IO.puts()
        IO.inspect(job)
        :ok
    end
  end

  def debug_jobs(job_id) do
    ["Debug", job_id, "Job ID is not valid"] |> Printer.title() |> IO.puts()
  end

  def retry_jobs([_ | _] = jobs_ids), do: Enum.each(jobs_ids, &retry_jobs/1)
  def retry_jobs([]), do: :ok

  def retry_jobs(job_id) when is_integer(job_id) do
    Repo.retry_job(job_id)
    ["Retried", job_id] |> Printer.title() |> IO.puts()
  end

  def retry_jobs(job_id) do
    ["Retry", job_id, "Job ID is not valid"] |> Printer.title() |> IO.puts()
  end

  def cancel_jobs([_ | _] = jobs_ids), do: Enum.each(jobs_ids, &cancel_jobs/1)
  def cancel_jobs([]), do: :ok

  def cancel_jobs(job_id) when is_integer(job_id) do
    Repo.cancel_job(job_id)
    ["Cancelled", job_id] |> Printer.title() |> IO.puts()
  end

  def cancel_jobs(job_id) do
    ["Cancel", job_id, "Job ID is not valid"] |> Printer.title() |> IO.puts()
  end

  def convert_states(states) do
    states
    |> Enum.map(fn
      "in_progress" -> @in_progress_states
      "failed" -> @failed_states
      state -> Map.get(@states, state, state)
    end)
    |> List.flatten()
  end

  defp ids_listed_before(opts) do
    case Keyword.get(opts, :ids, []) do
      nil -> []
      [0] -> Storage.get_last_jobs_ids()
      ids -> ids
    end
  end

  defp list_query(opts) do
    Oban.Job
    |> filter_by(:id, Keyword.get(opts, :ids))
    |> filter_by(:state, Keyword.get(opts, :states))
    |> filter_by(:queue, Keyword.get(opts, :queues))
    |> filter_by_workers(Keyword.get(opts, :workers))
    |> order_by(
      [j],
      fragment("CASE WHEN attempted_at IS NULL THEN '2050-12-30 00:00:00.000' ELSE attempted_at END")
    )
    |> order_by([j], desc: j.attempted_at)
    |> order_by([j], desc: j.scheduled_at)
    |> limit(^(Keyword.get(opts, :limit) || 20))
  end

  defp filter_by(query, _field, nil), do: query
  defp filter_by(query, _field, []), do: query
  defp filter_by(query, field, values), do: where(query, [j], field(j, ^field) in ^values)

  defp filter_by_workers(query, nil), do: query
  defp filter_by_workers(query, []), do: query

  defp filter_by_workers(query, workers) do
    {exclude, include} = Enum.split_with(workers, &String.contains?(&1, "-"))

    query
    |> apply_workers_like(Enum.map(include, &"%#{&1}%"), true)
    |> apply_workers_like(Enum.map(exclude, &String.replace("%#{&1}%", "-", "")), false)
  end

  defp apply_workers_like(query, [], _), do: query

  defp apply_workers_like(query, workers, true) do
    filter = Enum.reduce(workers, false, &dynamic([j], like(j.worker, ^&1) or ^&2))
    where(query, ^filter)
  end

  defp apply_workers_like(query, workers, false) do
    filter = Enum.reduce(workers, true, &dynamic([j], not like(j.worker, ^&1) and ^&2))
    where(query, ^filter)
  end
end
