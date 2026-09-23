defmodule ObanChore.Test.Chores.UserBackfill do
  use ObanChore.Worker,
    name: "User Backfill",
    description: "Backfills data for a single user.",
    fields: [
      user_id: [type: :integer, required: true, label: "User ID"],
      reason: [type: :string, default: "Manual run"]
    ]

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}} = job) do
    ObanChore.log(job, "Backfilling user #{user_id}")
    :ok
  end

  @impl ObanChore.Worker
  def custom_changeset(changeset) do
    validate_number(changeset, :user_id, greater_than: 0)
  end
end

defmodule ObanChore.Test.Chores.UniqueCleanup do
  use ObanChore.Worker,
    name: "Unique Cleanup",
    unique: [period: :infinity, states: [:available, :scheduled, :executing]],
    fields: [scope: [type: :string, required: true]]

  @impl Oban.Worker
  def perform(_job), do: :ok
end
