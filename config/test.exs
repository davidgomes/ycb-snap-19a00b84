import Config

config :oban_chore, ObanChore.TestRepo,
  username: System.get_env("POSTGRES_USER", "postgres"),
  password: System.get_env("POSTGRES_PASSWORD", "postgres"),
  hostname: System.get_env("POSTGRES_HOST", "localhost"),
  database: "oban_chore_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :oban_chore, ObanChore.TestEndpoint,
  url: [host: "localhost"],
  secret_key_base: String.duplicate("oban_chore_test_secret", 4),
  live_view: [signing_salt: "oban_chore_test"],
  server: false

config :oban_chore, :pubsub_server, ObanChore.TestPubSub

config :phoenix, :json_library, Jason

config :logger, level: :warning
