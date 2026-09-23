Logger.configure(level: :info)

File.mkdir_p!("db")

Application.put_env(:ocelot, Ocelot.DevRepo, database: "db/dev.db", pool_size: 5)

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
  def perform(%Oban.Job{args: %{"fail" => true}}), do: {:error, "intentional failure"}
  def perform(%Oban.Job{args: %{"sleep" => ms}}), do: Process.sleep(ms)
  def perform(%Oban.Job{}), do: :ok
end

defmodule Ocelot.DevRouter do
  use Plug.Router

  plug :match
  plug :dispatch

  forward "/oban", to: Ocelot.Router, init_opts: [oban: Oban]

  get "/" do
    conn
    |> put_resp_header("location", "/oban")
    |> send_resp(302, "")
  end
end

{:ok, _} =
  Supervisor.start_link([Ocelot.DevRepo], strategy: :one_for_one, name: Ocelot.DevRepoSup)

Ecto.Migrator.run(Ocelot.DevRepo, [{1, Ocelot.DevMigration}], :up, all: true)

{:ok, _} =
  Supervisor.start_link(
    [
      {Oban,
       engine: Oban.Engines.Lite,
       repo: Ocelot.DevRepo,
       queues: [default: 5],
       plugins: [{Oban.Plugins.Pruner, max_age: 3600}]},
      {Bandit, plug: Ocelot.DevRouter, port: 4000}
    ],
    strategy: :one_for_one,
    name: Ocelot.DevSup
  )

for changeset <- [
      Ocelot.DevWorker.new(%{"id" => 1}),
      Ocelot.DevWorker.new(%{"fail" => true}),
      Ocelot.DevWorker.new(%{"sleep" => 60_000}),
      Ocelot.DevWorker.new(%{"id" => 2}, schedule_in: 3600)
    ] do
  {:ok, _job} = Oban.insert(changeset)
end

IO.puts("Ocelot dashboard running at http://localhost:4000/oban")

# The supervisors above are linked to this script process, which must stay alive.
Process.sleep(:infinity)
