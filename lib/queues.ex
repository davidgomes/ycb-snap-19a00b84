defmodule Oban.Console.Queues do
  def get_queues() do
    Oban.config().queues
    |> Enum.map(fn {queue, _opts} -> Oban.check_queue(queue: queue) end)
  end

  def pause_queues(queues) do
    Enum.each(queues, &Oban.pause_queue(queue: &1))
  end

  def resume_queues(queues) do
    Enum.each(queues, &Oban.resume_queue(queue: &1))
  end
end
