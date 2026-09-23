Application.put_env(:ocelot, Ocelot.Dev.Repo, database: "ocelot_dev.db")

defmodule Ocelot.Dev.Repo do
  use Ecto.Repo, otp_app: :ocelot, adapter: Ecto.Adapters.SQLite3
end

defmodule Ocelot.Dev.Migration do
  use Ecto.Migration

  def up, do: Oban.Migration.up()
  def down, do: Oban.Migration.down()
end

defmodule Ocelot.Dev.Worker do
  use Oban.Worker

  @impl true
  def perform(%{args: %{"fail" => true}}), do: {:error, "boom"}
  def perform(_job), do: :ok
end

{:ok, _} = Ocelot.Dev.Repo.start_link()
Ecto.Migrator.run(Ocelot.Dev.Repo, [{0, Ocelot.Dev.Migration}], :up, all: true)

{:ok, _} =
  Oban.start_link(repo: Ocelot.Dev.Repo, engine: Oban.Engines.Lite, queues: [default: 5])

for i <- 1..10, do: Oban.insert!(Ocelot.Dev.Worker.new(%{n: i, fail: rem(i, 4) == 0}))

{:ok, _} = Bandit.start_link(plug: {Ocelot.Router, oban: Oban}, port: 4000)
IO.puts("Ocelot running at http://localhost:4000")
