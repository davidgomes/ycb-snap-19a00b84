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
      build(:job, id: 1, worker: "MyApp.Workers.Default", state: "available", queue: "default"),
      build(:job, id: 2, worker: "MyApp.Workers.Search", state: "executing", queue: "searching"),
      build(:job, id: 3, worker: "MyApp.Workers.Match", state: "completed", queue: "matching")
    ]
  end
end
