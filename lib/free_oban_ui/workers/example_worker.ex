defmodule FreeObanUi.Workers.ExampleWorker do
  @moduledoc """
  An example worker for testing and demonstrating background jobs in Oban UI.
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 5

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => "fail"}}) do
    raise "Intentional failure for testing Oban UI error handling"
  end

  def perform(%Oban.Job{args: %{"action" => "snooze", "duration" => duration}}) do
    {:snooze, duration}
  end

  def perform(%Oban.Job{args: args}) do
    # Simulate work
    {:ok, %{status: "processed", args: args}}
  end
end
