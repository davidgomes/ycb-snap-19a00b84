defmodule ObanConfigMock do
  import Factory

  def queues do
    [
      build(:queue, queue: "default", paused: true, local_limit: 10),
      build(:queue, queue: "searching", paused: false, local_limit: 15),
      build(:queue, queue: "matching", paused: true, local_limit: 20)
    ]
  end

  def jobs do
    [
      build(:job, id: 1, worker: "MyApp.Workers.SearchWorker", state: "completed", attempt: 1),
      build(:job,
        id: 2,
        worker: "MyApp.Workers.MatchWorker",
        state: "scheduled",
        queue: "matching"
      ),
      build(:job, id: 3, worker: "MyApp.Workers.SearchWorker", state: "discarded", attempt: 20)
    ]
  end
end
