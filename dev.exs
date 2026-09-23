# Development server: runs Oban on a local SQLite database with some sample
# jobs and serves the dashboard at http://localhost:4000/oban
#
#     mix dev

Logger.configure(level: :info)

Application.put_env(:ocelot, Ocelot.Dev.Repo, database: "db/dev.sqlite3")

defmodule Ocelot.Dev.Repo do
  use Ecto.Repo, otp_app: :ocelot, adapter: Ecto.Adapters.SQLite3
end

defmodule Ocelot.Dev.Migration do
  use Ecto.Migration

  def up, do: Oban.Migration.up()
  def down, do: Oban.Migration.down()
end

defmodule Ocelot.Dev.Worker do
  use Oban.Worker, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    Process.sleep(Map.get(args, "sleep", 0))

    case args do
      %{"outcome" => "error"} -> {:error, "something went wrong"}
      %{"outcome" => "raise"} -> raise ArgumentError, "invalid <input>"
      %{"outcome" => "cancel"} -> {:cancel, "no longer needed"}
      _ -> :ok
    end
  end
end

defmodule Ocelot.Dev.Router do
  use Plug.Router

  plug Plug.Logger
  plug :match
  plug :dispatch

  forward "/oban", to: Ocelot.Router

  match _ do
    conn
    |> put_resp_header("location", "/oban")
    |> send_resp(302, "")
  end
end

File.mkdir_p!("db")

Ecto.Migrator.with_repo(Ocelot.Dev.Repo, fn repo ->
  Ecto.Migrator.run(repo, [{1, Ocelot.Dev.Migration}], :up, all: true)
end)

{:ok, _} =
  Supervisor.start_link(
    [
      Ocelot.Dev.Repo,
      {Oban,
       repo: Ocelot.Dev.Repo,
       engine: Oban.Engines.Lite,
       queues: [default: 5, mailers: 2, reports: 1]},
      {Bandit, plug: Ocelot.Dev.Router, port: 4000}
    ],
    strategy: :one_for_one
  )

[
  Ocelot.Dev.Worker.new(%{"email" => "ocelot@example.com"}, queue: :mailers),
  Ocelot.Dev.Worker.new(%{"report" => "daily", "sleep" => 60_000}, queue: :reports),
  Ocelot.Dev.Worker.new(%{"report" => "weekly", "sleep" => 60_000}, queue: :reports),
  Ocelot.Dev.Worker.new(%{"outcome" => "error"}, tags: ["flaky"]),
  Ocelot.Dev.Worker.new(%{"outcome" => "raise"}, max_attempts: 1),
  Ocelot.Dev.Worker.new(%{"outcome" => "cancel"}),
  Ocelot.Dev.Worker.new(%{"cleanup" => true}, schedule_in: {5, :minutes}),
  Ocelot.Dev.Worker.new(%{"cleanup" => true}, schedule_in: {2, :hours})
]
|> Enum.each(&Oban.insert!/1)

# The supervisor shuts down when this process exits, so keep it alive.
Process.sleep(:infinity)
