defmodule Ocelot.TestRepo do
  use Ecto.Repo, otp_app: :ocelot, adapter: Ecto.Adapters.SQLite3
end

defmodule Ocelot.TestMigration do
  use Ecto.Migration

  def up, do: Oban.Migration.up()
  def down, do: Oban.Migration.down()
end

# An in-memory database only lives as long as its connection, hence the single-connection pool.
{:ok, _} = Ocelot.TestRepo.start_link(database: ":memory:", pool_size: 1, log: false)
Ecto.Migrator.up(Ocelot.TestRepo, 1, Ocelot.TestMigration, log: false)

{:ok, _} =
  Oban.start_link(
    name: Ocelot.TestOban,
    repo: Ocelot.TestRepo,
    engine: Oban.Engines.Lite,
    testing: :manual
  )

ExUnit.start()
