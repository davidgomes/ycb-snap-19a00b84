defmodule ObanChore.Test.BackfillChore do
  use ObanChore.Worker,
    name: "Backfill Chore",
    description: "Backfills data for a single user.",
    fields: [
      user_id: [type: :integer, required: true, label: "User ID"],
      reason: [type: :textarea, label: "Reason"]
    ]

  @impl ObanChore.Worker
  def custom_changeset(changeset) do
    validate_number(changeset, :user_id, greater_than: 0)
  end

  @impl Oban.Worker
  def perform(%Oban.Job{} = job) do
    ObanChore.log(job, "Backfilling user #{job.args["user_id"]}")
    :ok
  end
end

defmodule ObanChore.Test.UniqueChore do
  use ObanChore.Worker,
    name: "Unique Chore",
    fields: [account_id: [type: :integer, required: true]],
    unique: [period: :infinity, states: [:available, :scheduled, :executing]]

  @impl Oban.Worker
  def perform(_job), do: :ok
end
