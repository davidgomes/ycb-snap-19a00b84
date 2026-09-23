Application.put_env(:ocelot, Ocelot.Dev.Repo, database: "db/dev.db")

defmodule Ocelot.Dev.Repo do
  use Ecto.Repo, otp_app: :ocelot, adapter: Ecto.Adapters.SQLite3
end

defmodule Ocelot.Dev.Migration do
  use Ecto.Migration

  def up, do: Oban.Migration.up()
  def down, do: Oban.Migration.down()
end

defmodule Ocelot.Dev.Worker do
  use Oban.Worker, queue: :default, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"fail" => true}}), do: {:error, "intentional failure"}
  def perform(%Oban.Job{args: %{"sleep" => ms}}), do: Process.sleep(ms)
  def perform(_job), do: :ok
end

defmodule Ocelot.Dev.Router do
  use Plug.Router

  plug :match
  plug :dispatch

  forward "/oban", to: Ocelot.Router, init_opts: [oban: Oban]

  match "/" do
    conn
    |> put_resp_header("location", "/oban")
    |> send_resp(302, "")
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end
end

File.mkdir_p!("db")

{:ok, _} = Supervisor.start_link([Ocelot.Dev.Repo], strategy: :one_for_one)
Ecto.Migrator.run(Ocelot.Dev.Repo, [{1, Ocelot.Dev.Migration}], :up, all: true)

{:ok, _} =
  Supervisor.start_link(
    [
      {Oban,
       engine: Oban.Engines.Lite,
       repo: Ocelot.Dev.Repo,
       queues: [default: 5, mailers: 2],
       plugins: [{Oban.Plugins.Pruner, max_age: 3600}]},
      {Bandit, plug: Ocelot.Dev.Router, port: 4000}
    ],
    strategy: :one_for_one
  )

[
  Ocelot.Dev.Worker.new(%{"hello" => "world"}),
  Ocelot.Dev.Worker.new(%{"fail" => true}),
  Ocelot.Dev.Worker.new(%{"sleep" => 60_000}),
  Ocelot.Dev.Worker.new(%{"later" => true}, schedule_in: 3600),
  Ocelot.Dev.Worker.new(%{"to" => "someone@example.com"}, queue: :mailers, tags: ["email"])
]
|> Oban.insert_all()

IO.puts("Ocelot running at http://localhost:4000/oban")
