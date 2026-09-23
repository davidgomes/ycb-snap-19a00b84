alias GenQueue.Oban.Test.{Migration, Repo}

{:ok, _} = Repo.start_link()
Ecto.Migrator.up(Repo, 0, Migration, log: false)
{:ok, _} = Oban.start_link(repo: Repo, queues: false, prune: :disabled)

ExUnit.start()
