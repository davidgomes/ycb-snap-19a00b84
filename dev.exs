defmodule Ocelot.Dev.Repo do
  use Ecto.Repo, otp_app: :ocelot, adapter: Ecto.Adapters.SQLite3
end

defmodule Ocelot.Dev.Migration do
  use Ecto.Migration

  defdelegate up, to: Oban.Migration
  defdelegate down, to: Oban.Migration
end

defmodule Ocelot.Dev.Endpoint do
  use Plug.Builder

  plug Plug.Logger
  plug Ocelot.Router, oban_name: Ocelot.Dev.Oban
end

File.mkdir_p!("db")

repo_opts = [database: "db/ocelot_dev.sqlite3", pool_size: 2]

Application.put_env(:ocelot, Ocelot.Dev.Repo, repo_opts)

{:ok, _} = Ocelot.Dev.Repo.start_link(repo_opts)

Ecto.Migrator.run(Ocelot.Dev.Repo, [{1, Ocelot.Dev.Migration}], :up, all: true)

{:ok, _} =
  Oban.start_link(
    name: Ocelot.Dev.Oban,
    repo: Ocelot.Dev.Repo,
    engine: Oban.Engines.Lite,
    queues: [default: 1],
    plugins: false
  )

now = DateTime.utc_now() |> DateTime.truncate(:second)

for state <- ~w(available scheduled completed discarded) do
  Ocelot.Dev.Repo.insert!(%Oban.Job{
    args: %{"demo" => state},
    worker: "Ocelot.Dev.Worker",
    queue: "default",
    state: state,
    scheduled_at: now,
    inserted_at: now
  })
end

port = String.to_integer(System.get_env("PORT", "4000"))

{:ok, _} = Bandit.start_link(plug: Ocelot.Dev.Endpoint, port: port)

IO.puts("Ocelot dashboard running on http://localhost:#{port}")
