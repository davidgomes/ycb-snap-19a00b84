# Development server for Ocelot.
#
# Starts an Oban instance backed by a local SQLite database, keeps it busy
# with sample jobs and serves the dashboard at http://localhost:4000/oban.
#
#     mix dev

Application.put_env(:ocelot, Ocelot.Dev.Repo, database: Path.expand("db/dev.sqlite3"))

defmodule Ocelot.Dev.Repo do
  use Ecto.Repo, otp_app: :ocelot, adapter: Ecto.Adapters.SQLite3
end

defmodule Ocelot.Dev.Migration do
  use Ecto.Migration

  def up, do: Oban.Migration.up()
  def down, do: Oban.Migration.down()
end

defmodule Ocelot.Dev.Work do
  def perform(%Oban.Job{args: %{"simulate" => outcome}}) do
    Process.sleep(Enum.random(100..3_000))

    case outcome do
      "ok" -> :ok
      "error" -> {:error, "something went wrong"}
      "raise" -> raise ArgumentError, "unexpected input"
      "cancel" -> {:cancel, "no longer needed"}
      "snooze" -> {:snooze, 30}
    end
  end
end

defmodule Ocelot.Dev.Mailer do
  use Oban.Worker, queue: :mailers, max_attempts: 3

  @impl Oban.Worker
  defdelegate perform(job), to: Ocelot.Dev.Work
end

defmodule Ocelot.Dev.Thumbnailer do
  use Oban.Worker, queue: :media, max_attempts: 5

  @impl Oban.Worker
  defdelegate perform(job), to: Ocelot.Dev.Work
end

defmodule Ocelot.Dev.ReportBuilder do
  use Oban.Worker, queue: :default, max_attempts: 3

  @impl Oban.Worker
  defdelegate perform(job), to: Ocelot.Dev.Work
end

defmodule Ocelot.Dev.Seeder do
  use Task, restart: :permanent

  alias Ocelot.Dev.{Mailer, ReportBuilder, Thumbnailer}

  @outcomes ~w(ok ok ok ok ok ok ok error raise cancel snooze)

  def start_link(_opts), do: Task.start_link(&loop/0)

  defp loop do
    for _ <- 1..Enum.random(1..4), do: Oban.insert!(build_job())

    Process.sleep(2_000)
    loop()
  end

  defp build_job do
    id = System.unique_integer([:positive])

    opts = [
      priority: Enum.random(0..3),
      tags: Enum.take_random(~w(sample urgent batch), Enum.random(0..2))
    ]

    opts = if Enum.random(1..5) == 1, do: [schedule_in: Enum.random(10..120)] ++ opts, else: opts
    args = %{"simulate" => Enum.random(@outcomes)}

    case Enum.random([Mailer, Thumbnailer, ReportBuilder]) do
      Mailer ->
        args
        |> Map.merge(%{
          "to" => "user#{id}@example.com",
          "template" => Enum.random(~w(welcome receipt reset_password))
        })
        |> Mailer.new(opts)

      Thumbnailer ->
        args
        |> Map.merge(%{"image_id" => id, "sizes" => [64, 256, 1024]})
        |> Thumbnailer.new(opts)

      ReportBuilder ->
        args
        |> Map.merge(%{"account_id" => id, "period" => Enum.random(~w(daily weekly monthly))})
        |> ReportBuilder.new(opts)
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

port = String.to_integer(System.get_env("PORT", "4000"))

Task.start(fn ->
  Ecto.Migrator.with_repo(Ocelot.Dev.Repo, fn repo ->
    Ecto.Migrator.run(repo, [{1, Ocelot.Dev.Migration}], :up, all: true)
  end)

  children = [
    Ocelot.Dev.Repo,
    {Oban,
     engine: Oban.Engines.Lite,
     repo: Ocelot.Dev.Repo,
     queues: [default: 5, mailers: 10, media: 2],
     plugins: [{Oban.Plugins.Pruner, max_age: 3_600}]},
    Ocelot.Dev.Seeder,
    {Bandit, plug: Ocelot.Dev.Router, port: port}
  ]

  {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)

  IO.puts("Ocelot is running at http://localhost:#{port}/oban")

  Process.sleep(:infinity)
end)
