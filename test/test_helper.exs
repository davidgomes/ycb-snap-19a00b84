Logger.configure(level: :warn)

{:ok, _} = GenQueueOban.Repo.start_link()

ExUnit.start()
