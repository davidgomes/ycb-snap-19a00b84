defmodule FreeObanUi.Workers.ExampleWorker do
  @moduledoc """
  A demo worker that sleeps for a while and optionally fails, used to
  populate the jobs UI with some data.
  """

  use Oban.Worker, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    Process.sleep(Map.get(args, "sleep", 1_000))

    if Map.get(args, "fail", false) do
      {:error, "failed on purpose"}
    else
      :ok
    end
  end
end
