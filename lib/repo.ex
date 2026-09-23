defmodule Oban.Console.Repo do
  def queues do
    Enum.map(Oban.config().queues, fn {name, _} ->
      [queue: name]
      |> Oban.check_queue()
      |> Map.take([:queue, :paused, :local_limit])
    end)
  end

  def pause_queue(name), do: Oban.pause_queue(queue: name)
  def resume_queue(name), do: Oban.resume_queue(queue: name)

  def jobs(opts) do
    import Ecto.Query

    states = Keyword.get(opts, :states, [])
    limit = Keyword.get(opts, :limit, 20)

    Oban.Job
    |> then(fn q -> if states == [], do: q, else: where(q, [j], j.state in ^states) end)
    |> order_by([j], desc: j.id)
    |> limit(^limit)
    |> Oban.config().repo.all()
  end

  def cancel_job(id), do: Oban.cancel_job(id)
  def retry_job(id), do: Oban.retry_job(id)
end
