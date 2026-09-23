defmodule ObanChore.TestMigration do
  use Ecto.Migration

  def up, do: Oban.Migrations.up()
  def down, do: Oban.Migrations.down(version: 1)
end

alias ObanChore.TestRepo

_ = Ecto.Adapters.Postgres.storage_up(TestRepo.config())

{:ok, _} = TestRepo.start_link()
Ecto.Migrator.run(TestRepo, [{0, ObanChore.TestMigration}], :up, all: true, log: false)
Ecto.Adapters.SQL.Sandbox.mode(TestRepo, :manual)

{:ok, _} =
  Supervisor.start_link(
    [{Phoenix.PubSub, name: ObanChore.Test.PubSub}, ObanChoreWeb.TestEndpoint],
    strategy: :one_for_one
  )

ExUnit.start()
