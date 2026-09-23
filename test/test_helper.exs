{:ok, _} = GenQueue.ObanTest.Repo.start_link()

Application.put_env(:ex_unit, :assert_receive_timeout, 3_000)

ExUnit.start()
