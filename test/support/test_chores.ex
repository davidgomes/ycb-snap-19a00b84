defmodule ObanChore.TestChores.UserBackfill do
  use ObanChore.Worker,
    name: "User Backfill",
    description: "Backfills data for a single user.",
    fields: [
      user_id: [type: :integer, required: true, label: "User ID"],
      reason: [type: :string, default: "Manual update", label: "Reason"]
    ]

  @impl ObanChore.Worker
  def custom_changeset(changeset) do
    validate_number(changeset, :user_id, greater_than: 0)
  end

  @impl Oban.Worker
  def perform(_job), do: :ok
end

defmodule ObanChore.TestChores.AccountCleanup do
  use ObanChore.Worker,
    name: "Account Cleanup",
    unique: [period: 60],
    fields: [
      account_id: [type: :integer, required: true, label: "Account ID"]
    ]

  @impl Oban.Worker
  def perform(_job), do: :ok
end
