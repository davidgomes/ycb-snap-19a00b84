alias ObanChore.TestRepo

_ = Ecto.Adapters.Postgres.storage_up(TestRepo.config())

{:ok, _} = Supervisor.start_link([TestRepo], strategy: :one_for_one)

Ecto.Migrator.run(TestRepo, [{0, TestRepo.Migration}], :up, all: true, log: false)
Ecto.Adapters.SQL.Sandbox.mode(TestRepo, :manual)

{:ok, _} =
  Supervisor.start_link(
    [
      {Phoenix.PubSub, name: ObanChore.TestPubSub},
      ObanChore.TestEndpoint,
      {Oban, repo: TestRepo, testing: :manual}
    ],
    strategy: :one_for_one
  )

ExUnit.start()
