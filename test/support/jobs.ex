defmodule GenQueueOban.Test.Enqueuer do
  use GenQueue, otp_app: :gen_queue_oban
end

defmodule GenQueueOban.Test.Job do
  use Oban.Worker, queue: "events", max_attempts: 10

  @impl Oban.Worker
  def perform(_args, _job), do: :ok
end
