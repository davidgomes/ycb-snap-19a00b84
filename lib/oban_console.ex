defmodule Oban.Console do
  @moduledoc """
  Documentation for `ObanConsole`.
  """

  def list_queues() do
    Oban.Console.Queues.list()
  end

  def list_jobs(opts \\ []) do
    Oban.Console.Jobs.list(opts)
  end
end
