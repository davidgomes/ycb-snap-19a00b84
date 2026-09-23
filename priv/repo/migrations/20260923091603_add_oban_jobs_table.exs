defmodule FreeObanUi.Repo.Migrations.AddObanJobsTable do
  use Ecto.Migration

  def up do
    Oban.Migration.up(version: 12)
  end

  # Rolling back to version 1 removes Oban's tables entirely, regardless of
  # which version `up/0` migrated to.
  def down do
    Oban.Migration.down(version: 1)
  end
end
