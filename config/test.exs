import Config

config :oban_chore, ObanChore.TestRepo,
  username: System.get_env("POSTGRES_USER", "postgres"),
  password: System.get_env("POSTGRES_PASSWORD", "postgres"),
  hostname: System.get_env("POSTGRES_HOST", "localhost"),
  port: String.to_integer(System.get_env("POSTGRES_PORT", "5432")),
  database: "oban_chore_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :oban_chore, ObanChore.TestEndpoint,
  url: [host: "localhost"],
  secret_key_base: String.duplicate("oban_chore_test_secret_key_base", 3),
  live_view: [signing_salt: "oban_chore_test"],
  server: false

config :phoenix, :json_library, Jason

config :logger, level: :warning
