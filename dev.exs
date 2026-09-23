Application.put_env(:ocelot, Ocelot.Dev.Repo, database: "ocelot_dev.db")

defmodule Ocelot.Dev.Repo do
  use Ecto.Repo, otp_app: :ocelot, adapter: Ecto.Adapters.SQLite3
end

defmodule Ocelot.Dev.Migration do
  use Ecto.Migration

  def up, do: Oban.Migration.up()
  def down, do: Oban.Migration.down()
end

defmodule Ocelot.Dev.Endpoint do
  use Plug.Router

  plug :match
  plug :dispatch

  forward "/", to: Ocelot.Router, init_opts: [oban: Oban]
end

{:ok, _} = Ocelot.Dev.Repo.start_link()
Ecto.Migrator.run(Ocelot.Dev.Repo, [{0, Ocelot.Dev.Migration}], :up, all: true)

{:ok, _} =
  Supervisor.start_link(
    [
      {Oban, repo: Ocelot.Dev.Repo, engine: Oban.Engines.Lite, queues: false},
      {Bandit, plug: Ocelot.Dev.Endpoint, port: 4000}
    ],
    strategy: :one_for_one
  )
