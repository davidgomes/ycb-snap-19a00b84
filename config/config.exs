use Mix.Config

config :gen_queue_oban, ecto_repos: [GenQueueOban.Test.Repo]

config :gen_queue_oban, GenQueueOban.Test.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  database: "gen_queue_oban_test",
  pool_size: 10,
  log: false

config :gen_queue_oban, GenQueueOban.Test.Enqueuer,
  adapter: GenQueue.Adapters.Oban,
  repo: GenQueueOban.Test.Repo,
  queues: false,
  verbose: false
