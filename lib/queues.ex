defmodule Oban.Console.Queues do
  def list() do
    Enum.map(Oban.config().queues, fn {name, _} ->
      [queue: name]
      |> Oban.check_queue()
      |> Map.take([:queue, :paused, :local_limit])
    end)
  end

  def pause_queues([_ | _] = names), do: Enum.map(names, &pause_queues/1)
  def pause_queues([]), do: []

  def pause_queues(name) when is_binary(name) do
    Oban.pause_queue(queue: name)
    {:ok, name}
  end

  def pause_queues(name), do: {:error, name, "Queue name is not valid"}

  def resume_queues([_ | _] = names), do: Enum.map(names, &resume_queues/1)
  def resume_queues([]), do: []

  def resume_queues(name) when is_binary(name) do
    Oban.resume_queue(queue: name)
    {:ok, name}
  end

  def resume_queues(name), do: {:error, name, "Queue name is not valid"}
end
