import Config

config :oban_chore, ObanChore.Test.Repo,
  url:
    System.get_env(
      "DATABASE_URL",
      "postgres://postgres:postgres@localhost:5432/oban_chore_test"
    ),
  pool_size: 10

config :oban_chore, ObanChore.Test.Endpoint,
  secret_key_base: String.duplicate("oban_chore_test_secret", 4),
  live_view: [signing_salt: "oban_chore_test"],
  server: false

config :phoenix, :json_library, Jason

config :logger, level: :warning
