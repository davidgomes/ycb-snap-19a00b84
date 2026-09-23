defmodule GenQueue.Oban.Test.Job do
  use Oban.Worker, queue: "test"

  @impl Oban.Worker
  def perform(_args, _job), do: :ok
end

defmodule GenQueue.Oban.Test.Enqueuer do
  use GenQueue, otp_app: :gen_queue_oban
end

defmodule GenQueue.Oban.Test.MockEnqueuer do
  use GenQueue, otp_app: :gen_queue_oban
end
