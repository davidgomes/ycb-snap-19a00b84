defmodule GenQueue.Oban.Test.Enqueuer do
  use GenQueue, adapter: GenQueue.Adapters.Oban
end

defmodule GenQueue.Oban.Test.MockEnqueuer do
  use GenQueue, adapter: GenQueue.Adapters.MockJob
end

defmodule GenQueue.Oban.Test.Job do
  use Oban.Worker, queue: "events"

  @receiver :gen_queue_oban_test_receiver

  def receiver, do: @receiver

  @impl Oban.Worker
  def perform(args, _job) do
    case Process.whereis(@receiver) do
      nil -> :ok
      pid -> send(pid, {:performed, args})
    end
  end
end
