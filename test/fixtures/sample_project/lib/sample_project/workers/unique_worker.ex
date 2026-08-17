defmodule SampleProject.Workers.UniqueWorker do
  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    unique: [
      fields: [:args, :worker],
      keys: [:user_id],
      states: [:available, :scheduled, :executing, :retryable]
    ]

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    # Process user
    {:ok, user_id}
  end
end
