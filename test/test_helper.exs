alias GenQueueOban.Test.{Migration, Repo}

Repo.__adapter__().storage_up(Repo.config())
{:ok, _} = Repo.start_link()
Ecto.Migrator.up(Repo, 0, Migration, log: false)
{:ok, _} = Oban.start_link(repo: Repo, queues: false, prune: :disabled)

ExUnit.start()
