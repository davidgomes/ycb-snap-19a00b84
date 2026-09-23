alias GenQueue.Oban.Test.{Migration, Repo}

{:ok, _} = Repo.start_link()
Ecto.Migrator.run(Repo, [{0, Migration}], :up, all: true, log: false)
{:ok, _} = Oban.start_link(repo: Repo, queues: false, prune: :disabled)

ExUnit.start()
