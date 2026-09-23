defmodule ObanChore.Test.Migration do
  use Ecto.Migration

  def up, do: Oban.Migrations.up()
  def down, do: Oban.Migrations.down()
end

alias ObanChore.Test.Repo

_ = Ecto.Adapters.Postgres.storage_up(Repo.config())

{:ok, _} = Repo.start_link()

Ecto.Migrator.run(Repo, [{0, ObanChore.Test.Migration}], :up, all: true, log: false)
Ecto.Adapters.SQL.Sandbox.mode(Repo, :manual)

{:ok, _} =
  Supervisor.start_link(
    [
      {Phoenix.PubSub, name: ObanChore.Test.PubSub},
      {Oban, Application.fetch_env!(:oban_chore, Oban)},
      ObanChore.Test.Endpoint
    ],
    strategy: :one_for_one
  )

ExUnit.start()
