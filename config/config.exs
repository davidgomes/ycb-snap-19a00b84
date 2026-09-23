import Config

config :gen_queue_oban, ecto_repos: [GenQueueOban.Test.Repo]

config :gen_queue_oban, GenQueueOban.Test.Repo,
  database: "gen_queue_oban_test",
  hostname: "localhost",
  username: "postgres",
  password: "postgres",
  priv: "test/support/repo",
  log: false
