defmodule Oban.Console.Queues do
  @moduledoc """
  Functions to inspect and control Oban queues.
  """

  def get_queues() do
    Oban.config().queues
    |> Enum.map(fn {queue, _opts} -> Oban.check_queue(queue: queue) end)
    |> Enum.sort_by(& &1.queue)
  end

  def pause_queues(queues) when is_list(queues) do
    Enum.each(queues, &Oban.pause_queue(queue: &1))
  end

  def resume_queues(queues) when is_list(queues) do
    Enum.each(queues, &Oban.resume_queue(queue: &1))
  end
end
