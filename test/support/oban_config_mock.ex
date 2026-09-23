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
      build(:job, id: 1, worker: "MyApp.SearchWorker", state: "available", queue: "searching"),
      build(:job,
        id: 2,
        worker: "MyApp.MatchWorker",
        state: "executing",
        queue: "matching",
        attempt: 1,
        attempted_at: ~U[2024-01-01 10:05:00.000000Z]
      ),
      build(:job,
        id: 3,
        worker: "MyApp.DefaultWorker",
        state: "completed",
        queue: "default",
        attempt: 1,
        attempted_at: ~U[2024-01-01 10:10:00.000000Z]
      )
    ]
  end
end
