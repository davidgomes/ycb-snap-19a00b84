defmodule GenQueueOban.Test.Worker do
  use Oban.Worker, queue: "default", max_attempts: 10

  @impl Oban.Worker
  def perform(args, _job) do
    args
  end
end
