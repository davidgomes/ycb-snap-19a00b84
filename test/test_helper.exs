alias ObanChore.Test.Repo

case Ecto.Adapters.Postgres.storage_up(Repo.config()) do
  :ok -> :ok
  {:error, :already_up} -> :ok
  {:error, reason} -> raise "could not create the test database: #{inspect(reason)}"
end

{:ok, _} =
  Supervisor.start_link(
    [Repo, {Phoenix.PubSub, name: ObanChore.Test.PubSub}, ObanChore.Test.Endpoint],
    strategy: :one_for_one
  )

Ecto.Migrator.up(Repo, Oban.Migration.current_version(repo: Repo), ObanChore.Test.Migration,
  log: false
)

ExUnit.start()
