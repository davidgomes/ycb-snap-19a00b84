alias GenQueue.Oban.Test.{Enqueuer, Repo}

{:ok, _} = Repo.start_link()
{:ok, _} = Enqueuer.start_link(repo: Repo, queues: [events: 5])

Application.put_env(:ex_unit, :assert_receive_timeout, 3_000)

ExUnit.start()
