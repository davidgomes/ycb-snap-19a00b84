use Mix.Config

config :gen_queue_oban, ecto_repos: [GenQueue.Oban.Repo]

config :gen_queue_oban, GenQueue.Oban.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  database: "gen_queue_oban_test",
  pool_size: 10

config :logger, level: :warn
