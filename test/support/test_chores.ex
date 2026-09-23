defmodule ObanChore.TestChores.UserBackfill do
  use ObanChore.Worker,
    name: "User Backfill",
    description: "Backfills historical data for a user.",
    fields: [
      user_id: [type: :integer, required: true, label: "User ID"],
      reason: [type: :string, default: "manual", label: "Reason"]
    ]

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}} = job) do
    ObanChore.log(job, "Backfilling user #{user_id}")
    :ok
  end
end

defmodule ObanChore.TestChores.UniqueReindex do
  use ObanChore.Worker,
    name: "Unique Reindex",
    fields: [index: [type: :string, required: true]],
    unique: [period: :infinity]

  @impl Oban.Worker
  def perform(_job), do: :ok
end

defmodule ObanChore.TestChores.FailingChore do
  use ObanChore.Worker,
    name: "Failing Chore",
    fields: []

  @impl Oban.Worker
  def perform(_job), do: {:error, "boom"}
end
