defmodule SampleProject.Workers.ProWorker do
  use Oban.Pro.Worker,
    queue: :pro_queue,
    max_attempts: 10

  @impl Oban.Pro.Worker
  def process(%Oban.Job{args: args}) do
    {:ok, args}
  end
end
