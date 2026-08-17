defmodule SampleProject.Workers.EmailWorker do
  use Oban.Worker,
    queue: :emails,
    max_attempts: 5

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"to" => to, "subject" => subject}}) do
    # Send email
    {:ok, %{to: to, subject: subject}}
  end
end
