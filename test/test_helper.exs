{:ok, _} = GenQueueOban.Test.Repo.start_link()

ExUnit.start(assert_receive_timeout: 2_000)
