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
      build(:job, id: 1, state: "completed", attempted_at: ~N[2024-01-01 00:01:00]),
      build(:job, id: 2, state: "executing", queue: "searching"),
      build(:job, id: 3, state: "discarded", worker: "MyApp.OtherWorker")
    ]
  end
end
