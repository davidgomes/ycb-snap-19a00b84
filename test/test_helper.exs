Application.put_env(:ex_unit, :assert_receive_timeout, 3_000)

{:ok, _} = GenQueueOban.Test.Repo.start_link()

{:ok, _} =
  Oban.start_link(
    repo: GenQueueOban.Test.Repo,
    queues: [default: 10, events: 10, q1: 10],
    poll_interval: 100
  )

ExUnit.start()
