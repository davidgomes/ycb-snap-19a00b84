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
      build(:job, id: 1, state: "available", queue: "default", worker: "MyWorker"),
      build(:job, id: 2, state: "executing", queue: "searching", worker: "SearchWorker"),
      build(:job, id: 3, state: "completed", queue: "matching", worker: "MatchWorker")
    ]
  end
end
