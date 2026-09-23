import Config

config :oban_chore, ObanChore.Test.Repo,
  username: System.get_env("POSTGRES_USER", "postgres"),
  password: System.get_env("POSTGRES_PASSWORD", "postgres"),
  hostname: System.get_env("POSTGRES_HOST", "localhost"),
  database: "oban_chore_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :oban_chore, ObanChore.Test.Endpoint,
  secret_key_base: String.duplicate("oban_chore_test_secret", 4),
  live_view: [signing_salt: "oban_chore_lv"],
  server: false

config :oban_chore, Oban,
  repo: ObanChore.Test.Repo,
  notifier: Oban.Notifiers.Isolated,
  testing: :manual

config :phoenix, :json_library, Jason

config :logger, level: :warning
