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

  def jobs(query), do: Oban.config() |> Oban.Repo.all(query)
  def get_job(id), do: Oban.config() |> Oban.Repo.get(Oban.Job, id)
  def retry_job(id), do: Oban.retry_job(id)
  def cancel_job(id), do: Oban.cancel_job(id)
end
