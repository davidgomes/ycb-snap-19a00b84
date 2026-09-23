import Config

config :gen_queue_oban, GenQueueOban.Test.Repo,
  url:
    System.get_env("DATABASE_URL", "postgres://postgres:postgres@localhost/gen_queue_oban_test")

config :gen_queue_oban, GenQueueOban.Test.Enqueuer, adapter: GenQueue.Adapters.Oban

config :logger, level: :warn
