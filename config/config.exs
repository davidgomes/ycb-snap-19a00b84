import Config

if Mix.env() == :test do
  config :gen_queue_oban, ecto_repos: [GenQueueOban.Test.Repo]

  config :gen_queue_oban, GenQueueOban.Test.Repo,
    priv: "test/support/",
    url:
      System.get_env("DATABASE_URL") ||
        "postgres://postgres:postgres@localhost:5432/gen_queue_oban_test"

  config :logger, level: :warn
end
