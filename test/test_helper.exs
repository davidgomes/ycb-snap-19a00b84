ExUnit.start()

if System.get_env("CI") do
  Code.put_compiler_option(:warnings_as_errors, true)
end

{:ok, _} = Application.ensure_all_started(:postgrex)

{:ok, _} = EctoShorts.Support.Repo.start_link()

{:ok, _} = EctoShorts.Support.TestRepo.start_link(
  username: "postgres",
  password: "postgres",
  database: "ecto_shorts_test",
  hostname: "127.0.0.1",
  show_sensitive_data_on_connection_error: true,
  log: :debug,
  stacktrace: true,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 5
)
