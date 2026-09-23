import Config

if Mix.env() == :test do
  config :gen_queue_oban, ecto_repos: [GenQueue.Oban.Test.Repo]

  config :gen_queue_oban, GenQueue.Oban.Test.Repo,
    database: "gen_queue_oban_test",
    username: System.get_env("PGUSER", "postgres"),
    password: System.get_env("PGPASSWORD", "postgres"),
    hostname: System.get_env("PGHOST", "localhost"),
    priv: "test/support/repo",
    pool_size: 10

  config :logger, level: :warn
end
