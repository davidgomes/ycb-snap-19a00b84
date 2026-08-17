defmodule FreeObanUi.Workers.ExampleWorker do
  @moduledoc """
  A sample worker used to demonstrate and seed Oban jobs for the dashboard.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => "fail"}}) do
    raise "simulated failure"
  end

  def perform(%Oban.Job{args: args}) do
    {:ok, args}
  end
end
