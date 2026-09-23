use Mix.Config

if Mix.env() == :test do
  config :gen_queue_oban, ecto_repos: [GenQueue.ObanTest.Repo]

  config :gen_queue_oban, GenQueue.ObanTest.Repo,
    priv: "test/support/",
    url: System.get_env("DATABASE_URL") || "postgres://localhost:5432/gen_queue_oban_test"

  config :logger, level: :warn
end
