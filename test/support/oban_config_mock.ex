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
      build(:job, id: 1, state: "available", queue: "default"),
      build(:job,
        id: 2,
        state: "completed",
        queue: "searching",
        attempt: 1,
        worker: "MyApp.Workers.SearchWorker",
        attempted_at: ~U[2024-01-01 10:05:00Z]
      ),
      build(:job, id: 3, state: "scheduled", queue: "matching")
    ]
  end
end
