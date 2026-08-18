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
    states = convert_states(Keyword.get(opts, :states, [])) || []
    ids = ids_listed_before(opts)

    opts =
      opts
      |> Keyword.put(:ids, ids)
      |> Keyword.put(:states, states)
      |> Keyword.put(:limit, limit)

    response = list(opts)

    if Storage.get_last_jobs_opts() != opts do
      Storage.add_job_filter_history(opts)
    end

    Storage.set_last_jobs_ids(Enum.map(response, & &1.id))
    Storage.set_last_jobs_opts(opts)

    filters =
      Enum.reject(opts, fn
        {_, nil} -> true
        {_, []} -> true
        {_, _} -> false
      end)

    current_time = Calendar.strftime(DateTime.utc_now(), "%Y-%m-%d %H:%M:%S")

    Table.show(
      response,
      headers,
      "[#{current_time}] Rows: #{length(response)} Filters: #{inspect(filters)} Sorts: DESC attempted_at, DESC scheduled_at"
    )
  rescue
    error ->
      Printer.red(inspect(error)) |> IO.puts()
      Storage.set_last_jobs_opts([])
      show_list()
  end

  def clean_storage, do: Storage.set_last_jobs_opts([])

  def debug_jobs([_ | _] = job_ids), do: Enum.each(job_ids, &debug_jobs/1)
  def debug_jobs([]), do: :ok

  def debug_jobs(job_id) when is_integer(job_id) do
    Oban
    |> Oban.config()
    |> Oban.Repo.get(Oban.Job, job_id)
    |> then(fn
      nil ->
        ["Job", job_id, "Job not found"] |> Printer.title() |> IO.puts()

      job ->
        ["Job", job_id] |> Printer.title() |> IO.puts()
        IO.inspect(job)
    end)
  end

  def debug_jobs(job_id) do
    ["Debug", job_id, "Job ID is not valid"] |> Printer.title() |> IO.puts()
  end

  def retry_jobs([_ | _] = job_ids), do: Enum.each(job_ids, &retry_jobs/1)
  def retry_jobs([]), do: :ok

  def retry_jobs(job_id) when is_integer(job_id) do
    Oban.retry_job(job_id)
    ["Retried", job_id] |> Printer.title() |> IO.puts()
  end

  def retry_jobs(job_id) do
    ["Retry", job_id, "Job ID is not valid"] |> Printer.title() |> IO.puts()
  end

  def cancel_jobs([_ | _] = job_ids), do: Enum.each(job_ids, &cancel_jobs/1)
  def cancel_jobs([]), do: :ok

  def cancel_jobs(job_id) when is_integer(job_id) do
    Oban.cancel_job(job_id)
    ["Cancelled", job_id] |> Printer.title() |> IO.puts()
  end

  def cancel_jobs(job_id) do
    ["Cancel", job_id, "Job ID is not valid"] |> Printer.title() |> IO.puts()
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
    |> filter_by_ids(Keyword.get(opts, :ids))
    |> filter_by_states(Keyword.get(opts, :states))
    |> filter_by_queues(Keyword.get(opts, :queues))
    |> filter_by_workers(Keyword.get(opts, :workers))
    |> sort_by_attempted_at()
    |> sort_by_scheduled_at()
    |> limit_by(Keyword.get(opts, :limit))
  end

  defp convert_states(states) do
    states
    |> Enum.map(fn
      "in_progress" -> @in_progress_states
      "failed" -> @failed_states
      state when state in ["1", "2", "3", "4", "5", "6", "7"] -> Map.fetch!(@states, state)
      state -> state
    end)
    |> List.flatten()
  end

  defp filter_by_ids(query, nil), do: query
  defp filter_by_ids(query, []), do: query
  defp filter_by_ids(query, ids), do: where(query, [job], job.id in ^ids)

  defp filter_by_states(query, nil), do: query
  defp filter_by_states(query, []), do: query
  defp filter_by_states(query, states), do: where(query, [job], job.state in ^states)

  defp filter_by_queues(query, nil), do: query
  defp filter_by_queues(query, []), do: query
  defp filter_by_queues(query, queues), do: where(query, [job], job.queue in ^queues)

  defp filter_by_workers(query, nil), do: query
  defp filter_by_workers(query, []), do: query

  defp filter_by_workers(query, workers) do
    statements =
      Enum.reduce(workers, %{include: [], exclude: []}, fn worker, acc ->
        if String.starts_with?(worker, "-") do
          Map.update!(acc, :exclude, &["%#{String.trim_leading(worker, "-")}%" | &1])
        else
          Map.update!(acc, :include, &["%#{worker}%" | &1])
        end
      end)

    query
    |> apply_workers_like(statements.include, true)
    |> apply_workers_like(statements.exclude, false)
  end

  defp apply_workers_like(query, [], _include?), do: query

  defp apply_workers_like(query, workers, true) do
    filter =
      Enum.reduce(workers, dynamic(false), fn pattern, filter ->
        dynamic([job], like(job.worker, ^pattern) or ^filter)
      end)

    where(query, ^filter)
  end

  defp apply_workers_like(query, workers, false) do
    filter =
      Enum.reduce(workers, dynamic(true), fn pattern, filter ->
        dynamic([job], not like(job.worker, ^pattern) and ^filter)
      end)

    where(query, ^filter)
  end

  defp limit_by(query, nil), do: limit(query, 20)
  defp limit_by(query, limit), do: limit(query, ^limit)

  defp sort_by_attempted_at(query) do
    query
    |> order_by(
      [job],
      fragment(
        "CASE WHEN attempted_at IS NULL THEN '2050-12-30 00:00:00.000' ELSE attempted_at END"
      )
    )
    |> order_by([job], desc: job.attempted_at)
  end

  defp sort_by_scheduled_at(query), do: order_by(query, [job], desc: job.scheduled_at)
end
