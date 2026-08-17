import Config

config :gen_queue_oban, Oban,
  repo: GenQueue.Adapters.Oban.Repo,
  queues: [default: 10, events: 10]

config :gen_queue_oban, GenQueue.Adapters.Oban.Repo,
  priv: "priv/repo",
  pool: Ecto.Adapters.SQL.Sandbox
