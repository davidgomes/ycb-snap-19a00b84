defmodule Oban.Console.Queues do
  @moduledoc """
  Helpers to inspect and control Oban queues.
  """

  def get_queues(oban_name \\ Oban) do
    oban_name
    |> Oban.config()
    |> Map.get(:queues, [])
    |> Enum.map(fn {queue, _opts} -> Oban.check_queue(oban_name, queue: queue) end)
  end

  def pause_queues(queues, oban_name \\ Oban) when is_list(queues) do
    Enum.each(queues, &Oban.pause_queue(oban_name, queue: &1))
  end

  def resume_queues(queues, oban_name \\ Oban) when is_list(queues) do
    Enum.each(queues, &Oban.resume_queue(oban_name, queue: &1))
  end
end
