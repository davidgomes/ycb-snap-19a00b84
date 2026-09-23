use Mix.Config

if Mix.env() == :test do
  config :logger, level: :warn

  config :gen_queue_oban, ecto_repos: [GenQueueOban.TestRepo]

  config :gen_queue_oban, GenQueueOban.TestRepo,
    priv: "test/support/repo",
    database: "gen_queue_oban_test",
    username: System.get_env("POSTGRES_USER") || "postgres",
    password: System.get_env("POSTGRES_PASSWORD") || "postgres",
    hostname: System.get_env("POSTGRES_HOST") || "localhost",
    pool_size: 10

  config :gen_queue_oban, GenQueueOban.Enqueuer,
    adapter: GenQueue.Adapters.Oban,
    repo: GenQueueOban.TestRepo,
    queues: false
end
