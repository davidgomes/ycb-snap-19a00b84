alias GenQueueOban.Test.{Enqueuer, Migration, Repo}

Repo.__adapter__().storage_up(Repo.config())

{:ok, _} = Repo.start_link()

Ecto.Migrator.run(Repo, [{1, Migration}], :up, all: true, log: false)

{:ok, _} = Enqueuer.start_link()

ExUnit.start()
