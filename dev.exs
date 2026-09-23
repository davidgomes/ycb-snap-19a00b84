# Development server for Ocelot. Run with `mix dev` and open http://localhost:4000

Application.put_env(:ocelot, Ocelot.Dev.Repo, database: "db/dev.db", pool_size: 1)

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
    Process.sleep(Map.get(args, "sleep", 500))

    case args["outcome"] do
      "error" -> {:error, "something went wrong"}
      "cancel" -> {:cancel, "no longer needed"}
      "raise" -> raise "boom"
      _ -> :ok
    end
  end
end

defmodule Ocelot.Dev.Seeder do
  use Task

  def start_link(_opts), do: Task.start_link(&loop/0)

  defp loop do
    queue = Enum.random(~w(default mailers events))
    outcome = Enum.random(~w(ok ok ok ok error cancel raise))

    %{outcome: outcome, sleep: Enum.random(100..3_000)}
    |> Ocelot.Dev.Worker.new(queue: queue, schedule_in: Enum.random([0, 0, 0, 30, 120]))
    |> Oban.insert!()

    Process.sleep(1_000)
    loop()
  end
end

defmodule Ocelot.Dev.Router do
  use Plug.Router

  plug :match
  plug :dispatch

  forward "/oban", to: Ocelot.Router, init_opts: [oban: Oban]

  match _ do
    conn
    |> put_resp_header("location", "/oban")
    |> send_resp(302, "")
  end
end

File.mkdir_p!("db")

# Supervisors are unlinked so they outlive this script under `mix run --no-halt`.
{:ok, repo_sup} =
  Supervisor.start_link([Ocelot.Dev.Repo], strategy: :one_for_one, name: Ocelot.Dev.RepoSup)

Process.unlink(repo_sup)

Ecto.Migrator.run(Ocelot.Dev.Repo, [{1, Ocelot.Dev.Migration}], :up, all: true)

{:ok, sup} =
  Supervisor.start_link(
    [
      {Oban,
       engine: Oban.Engines.Lite,
       notifier: Oban.Notifiers.PG,
       repo: Ocelot.Dev.Repo,
       queues: [default: 5, mailers: 2, events: 3],
       plugins: [{Oban.Plugins.Pruner, max_age: 600}]},
      Ocelot.Dev.Seeder,
      {Bandit, plug: Ocelot.Dev.Router, port: 4000}
    ],
    strategy: :one_for_one,
    name: Ocelot.Dev.Supervisor
  )

Process.unlink(sup)
