defmodule ObanChore.TestRepo.Migrations.AddObanJobsTable do
  use Ecto.Migration

  def up, do: Oban.Migration.up()
  def down, do: Oban.Migration.down(version: 1)
end

repo = ObanChore.TestRepo

_ = Ecto.Adapters.Postgres.storage_up(repo.config())

{:ok, _} = Supervisor.start_link([repo, ObanChore.TestEndpoint], strategy: :one_for_one)

# Versioning the migration after Oban's own keeps an existing test database in sync when Oban
# ships new migrations.
Ecto.Migrator.up(
  repo,
  Oban.Migration.current_version(repo: repo),
  ObanChore.TestRepo.Migrations.AddObanJobsTable,
  log: false
)

{:ok, _} = Supervisor.start_link([{Oban, repo: repo, testing: :manual}], strategy: :one_for_one)

Ecto.Adapters.SQL.Sandbox.mode(repo, :manual)

ExUnit.start()
