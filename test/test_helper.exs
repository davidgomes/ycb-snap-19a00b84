defmodule GenQueue.ObanTest.Repo do
  use Ecto.Repo, otp_app: :gen_queue_oban, adapter: Ecto.Adapters.Postgres
end

defmodule GenQueue.ObanTest.Migration do
  use Ecto.Migration

  def up, do: Oban.Migrations.up()
  def down, do: Oban.Migrations.down()
end

alias GenQueue.ObanTest.{Migration, Repo}

Application.put_env(:gen_queue_oban, Repo,
  url:
    System.get_env("DATABASE_URL") ||
      "postgres://postgres:postgres@localhost/gen_queue_oban_test",
  log: false
)

_ = Ecto.Adapters.Postgres.storage_up(Repo.config())
{:ok, _} = Repo.start_link()
Ecto.Migrator.up(Repo, 20_190_101_000_000, Migration, log: false)

Application.put_env(:ex_unit, :assert_receive_timeout, 3_000)

ExUnit.start()
