import Config

config :oban_doctor, ObanDoctor.Test.Repo,
  database: "oban_doctor_test",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :oban_doctor, ecto_repos: [ObanDoctor.Test.Repo]

config :logger, level: :warning
