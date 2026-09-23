use Mix.Config

if Mix.env() == :test do
  config :gen_queue_oban, ecto_repos: [GenQueue.Oban.Test.Repo]

  config :gen_queue_oban, GenQueue.Oban.Test.Repo,
    username: System.get_env("POSTGRES_USER") || "postgres",
    password: System.get_env("POSTGRES_PASSWORD") || "postgres",
    hostname: System.get_env("POSTGRES_HOST") || "localhost",
    database: "gen_queue_oban_test",
    priv: "test/support/repo",
    pool: Ecto.Adapters.SQL.Sandbox

  config :gen_queue_oban, GenQueue.Oban.Test.Enqueuer, adapter: GenQueue.Adapters.Oban
  config :gen_queue_oban, GenQueue.Oban.Test.MockEnqueuer, adapter: GenQueue.Adapters.MockJob

  config :logger, level: :warn
end
