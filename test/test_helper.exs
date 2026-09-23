alias GenQueue.Oban.Test.Repo

{:ok, _} = Repo.start_link()
{:ok, _} = Oban.start_link(repo: Repo, queues: false, prune: :disabled)

Ecto.Adapters.SQL.Sandbox.mode(Repo, :manual)

ExUnit.start()
