defmodule GenQueue.Adapters.Oban.TestJob do
  use Oban.Worker, queue: "events", max_attempts: 10

  @impl Oban.Worker
  def perform(args, _job) do
    {:ok, args}
  end
end
