import Config

config :oban_chore, ObanChore.TestRepo,
  username: System.get_env("POSTGRES_USER", "postgres"),
  password: System.get_env("POSTGRES_PASSWORD", "postgres"),
  hostname: System.get_env("POSTGRES_HOST", "localhost"),
  database: "oban_chore_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :oban_chore, ObanChoreWeb.TestEndpoint,
  url: [host: "localhost"],
  secret_key_base: String.duplicate("oban_chore_test_secret_key_base", 3),
  live_view: [signing_salt: "oban_chore_test_salt"],
  pubsub_server: ObanChore.Test.PubSub,
  server: false

config :phoenix, :json_library, Jason

config :logger, level: :warning
