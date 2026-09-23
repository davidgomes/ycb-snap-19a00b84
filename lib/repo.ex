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

  def jobs(query), do: Oban.Repo.all(Oban.config(), query)
  def get_job(job_id), do: Oban.Repo.get(Oban.config(), Oban.Job, job_id)
  def retry_job(job_id), do: Oban.retry_job(job_id)
  def cancel_job(job_id), do: Oban.cancel_job(job_id)
end
