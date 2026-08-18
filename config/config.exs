use Mix.Config

config :gen_queue_oban, ecto_repos: [GenQueueOban.Repo]

config :gen_queue_oban, GenQueueOban.Repo,
  priv: "test/support/",
  url: System.get_env("DATABASE_URL") || "postgres://localhost:5432/gen_queue_oban_test"
