use Mix.Config

if Mix.env() == :test do
  config :gen_queue_oban, ecto_repos: [GenQueue.Oban.Test.Repo]

  config :gen_queue_oban, GenQueue.Oban.Test.Repo,
    database: "gen_queue_oban_test",
    username: System.get_env("POSTGRES_USER") || "postgres",
    password: System.get_env("POSTGRES_PASSWORD") || "",
    hostname: System.get_env("POSTGRES_HOST") || "localhost"

  config :logger, level: :warn
end
