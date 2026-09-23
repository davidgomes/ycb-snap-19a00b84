database = Path.join(System.tmp_dir!(), "ocelot_test.sqlite3")
for suffix <- ["", "-shm", "-wal"], do: File.rm(database <> suffix)

Application.put_env(:ocelot, Ocelot.Test.Repo,
  database: database,
  pool: Ecto.Adapters.SQL.Sandbox
)

defmodule Ocelot.Test.Repo do
  use Ecto.Repo, otp_app: :ocelot, adapter: Ecto.Adapters.SQLite3
end

defmodule Ocelot.Test.Migration do
  use Ecto.Migration

  def up, do: Oban.Migration.up()
  def down, do: Oban.Migration.down()
end

{:ok, _} = Ocelot.Test.Repo.start_link()
Ecto.Migrator.run(Ocelot.Test.Repo, [{1, Ocelot.Test.Migration}], :up, all: true, log: false)
{:ok, _} = Oban.start_link(engine: Oban.Engines.Lite, repo: Ocelot.Test.Repo, testing: :manual)
Ecto.Adapters.SQL.Sandbox.mode(Ocelot.Test.Repo, :manual)

ExUnit.start()
