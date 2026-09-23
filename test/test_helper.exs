defmodule ObanChore.TestMigration do
  use Ecto.Migration

  def up, do: Oban.Migration.up()
  def down, do: Oban.Migration.down()
end

alias ObanChore.TestRepo

_ = Ecto.Adapters.Postgres.storage_up(TestRepo.config())

{:ok, _} = TestRepo.start_link()
Ecto.Migrator.up(TestRepo, 1, ObanChore.TestMigration, log: false)
Ecto.Adapters.SQL.Sandbox.mode(TestRepo, :manual)

{:ok, _} = ObanChore.TestEndpoint.start_link()
{:ok, _} = Oban.start_link(repo: TestRepo, testing: :manual)

ExUnit.start()
