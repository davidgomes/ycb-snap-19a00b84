defmodule FreeObanUi.Workers.ExampleWorker do
  @moduledoc """
  A sample worker used to populate the jobs dashboard with realistic data.

  Pass `%{"fail" => true}` as the job args to simulate a failing job.
  """

  use Oban.Worker, queue: :default, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"fail" => true}}) do
    {:error, "simulated failure"}
  end

  def perform(%Oban.Job{}), do: :ok
end
