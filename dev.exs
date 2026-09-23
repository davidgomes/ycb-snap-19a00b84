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
  use Oban.Worker, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    Process.sleep(Map.get(args, "sleep", 0))

    case args["outcome"] do
      "error" -> {:error, "something went wrong"}
      "cancel" -> {:cancel, "no longer needed"}
      "raise" -> raise "boom"
      _ -> :ok
    end
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

{:ok, sup} = Supervisor.start_link([Ocelot.Dev.Repo], strategy: :one_for_one)
Process.unlink(sup)

Ecto.Migrator.run(Ocelot.Dev.Repo, [{0, Ocelot.Dev.Migration}], :up, all: true, log: false)

{:ok, _} =
  Supervisor.start_child(
    sup,
    {Oban,
     engine: Oban.Engines.Lite,
     notifier: Oban.Notifiers.PG,
     repo: Ocelot.Dev.Repo,
     queues: [default: 5, mailers: 2, media: 1]}
  )

{:ok, _} = Supervisor.start_child(sup, {Bandit, plug: Ocelot.Dev.Router, port: 4000})

for n <- 1..40 do
  queue = Enum.random(~w(default mailers media))
  outcome = Enum.random(~w(ok ok ok error cancel raise))
  schedule_in = if rem(n, 8) == 0, do: 3600, else: 0

  %{n: n, outcome: outcome, sleep: Enum.random(0..3_000)}
  |> Ocelot.Dev.Worker.new(queue: queue, schedule_in: schedule_in)
  |> Oban.insert!()
end

IO.puts("Ocelot running at http://localhost:4000/oban")
