# Development server: `mix dev`, then visit http://localhost:4000/oban

Application.put_env(:ocelot, Ocelot.DevRepo, database: "db/dev.db", pool_size: 1)

defmodule Ocelot.DevRepo do
  use Ecto.Repo, otp_app: :ocelot, adapter: Ecto.Adapters.SQLite3
end

defmodule Ocelot.DevMigration do
  use Ecto.Migration

  def up, do: Oban.Migration.up()
  def down, do: Oban.Migration.down()
end

defmodule Ocelot.DevWorker do
  use Oban.Worker, queue: :default, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"outcome" => "error"}}), do: {:error, "something went wrong"}
  def perform(%Oban.Job{args: %{"outcome" => "raise"}}), do: raise("boom")
  def perform(%Oban.Job{args: %{"outcome" => "cancel"}}), do: {:cancel, "no longer needed"}
  def perform(%Oban.Job{args: %{"sleep" => ms}}), do: Process.sleep(ms)
  def perform(_job), do: :ok
end

defmodule Ocelot.DevRouter do
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  get "/" do
    conn
    |> put_resp_header("location", "/oban")
    |> send_resp(302, "")
  end

  forward("/oban", to: Ocelot)

  match _ do
    send_resp(conn, 404, "Not found")
  end
end

File.mkdir_p!("db")

{:ok, sup} = Supervisor.start_link([Ocelot.DevRepo], strategy: :one_for_one)

# `mix run` exits the process that evaluates this script, which would take a linked supervisor down.
Process.unlink(sup)

Ecto.Migrator.run(Ocelot.DevRepo, [{1, Ocelot.DevMigration}], :up, all: true)

{:ok, _} =
  Supervisor.start_child(
    sup,
    {Oban, repo: Ocelot.DevRepo, engine: Oban.Engines.Lite, queues: [default: 5, mailers: 2]}
  )

{:ok, _} = Supervisor.start_child(sup, {Bandit, plug: Ocelot.DevRouter, port: 4000})

[
  %{"outcome" => "ok", "user_id" => 1},
  %{"outcome" => "error"},
  %{"outcome" => "raise"},
  %{"outcome" => "cancel"},
  %{"sleep" => 60_000}
]
|> Enum.map(&Ocelot.DevWorker.new/1)
|> Enum.concat([
  Ocelot.DevWorker.new(%{"outcome" => "ok"}, schedule_in: 3600),
  Ocelot.DevWorker.new(%{"email" => "<script>alert(1)</script>"}, queue: :mailers)
])
|> Enum.each(&Oban.insert!/1)
