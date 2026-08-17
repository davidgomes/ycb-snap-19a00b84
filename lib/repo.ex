defmodule Oban.Console.Repo do
  import Ecto.Query

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

  def queues do
    Enum.map(Oban.config().queues, fn {name, _} ->
      [queue: name]
      |> Oban.check_queue()
      |> Map.take([:queue, :paused, :local_limit])
    end)
  end

  def pause_queue(name), do: Oban.pause_queue(queue: name)
  def resume_queue(name), do: Oban.resume_queue(queue: name)

  def jobs(opts \\ []) do
    Oban
    |> Oban.config()
    |> Oban.Repo.all(list_query(opts))
  end

  def get_job(job_id) do
    Oban
    |> Oban.config()
    |> Oban.Repo.get(Oban.Job, job_id)
  end

  def retry_job(job_id), do: Oban.retry_job(job_id)

  def cancel_job(job_id), do: Oban.cancel_job(job_id)

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

  defp filter_by_ids(query, nil), do: query
  defp filter_by_ids(query, []), do: query
  defp filter_by_ids(query, ids), do: where(query, [j], j.id in ^ids)

  defp filter_by_states(query, nil), do: query
  defp filter_by_states(query, []), do: query
  defp filter_by_states(query, states), do: where(query, [j], j.state in ^states)

  defp filter_by_queues(query, nil), do: query
  defp filter_by_queues(query, []), do: query
  defp filter_by_queues(query, queues), do: where(query, [j], j.queue in ^queues)

  defp filter_by_workers(query, nil), do: query
  defp filter_by_workers(query, []), do: query

  defp filter_by_workers(query, workers) do
    statements =
      Enum.reduce(workers, %{include: [], exclude: []}, fn worker, acc ->
        case String.contains?(worker, "-") do
          true -> Map.put(acc, :exclude, [String.replace("%#{worker}%", "-", "") | acc[:exclude]])
          false -> Map.put(acc, :include, ["%#{worker}%" | acc[:include]])
        end
      end)

    query
    |> apply_workers_like(statements[:include], true)
    |> apply_workers_like(statements[:exclude], false)
  end

  defp apply_workers_like(query, [], _), do: query

  defp apply_workers_like(query, workers, true) do
    dynamic_filter = false

    dynamic_filter =
      Enum.reduce(workers, dynamic_filter, fn pattern, dynamic_filter ->
        dynamic([j], like(j.worker, ^pattern) or ^dynamic_filter)
      end)

    where(query, ^dynamic_filter)
  end

  defp apply_workers_like(query, workers, false) do
    dynamic_filter = true

    dynamic_filter =
      Enum.reduce(workers, dynamic_filter, fn pattern, dynamic_filter ->
        dynamic([j], not like(j.worker, ^pattern) and ^dynamic_filter)
      end)

    where(query, ^dynamic_filter)
  end

  defp limit_by(query, nil), do: limit(query, 20)
  defp limit_by(query, limit), do: limit(query, ^limit)

  defp sort_by_attempted_at(query) do
    query
    |> order_by(
      [j],
      fragment(
        "CASE WHEN attempted_at IS NULL THEN '2050-12-30 00:00:00.000' ELSE attempted_at END"
      )
    )
    |> order_by([j], desc: j.attempted_at)
  end

  defp sort_by_scheduled_at(query), do: order_by(query, [j], desc: j.scheduled_at)
end
