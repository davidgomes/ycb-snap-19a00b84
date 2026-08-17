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
      build(:job,
        id: 1,
        worker: "Worker1",
        state: "executing",
        queue: "default",
        attempt: 1,
        inserted_at: ~N[2026-01-01 00:00:00],
        attempted_at: ~N[2026-01-01 00:00:01],
        scheduled_at: ~N[2026-01-01 00:00:00]
      ),
      build(:job,
        id: 2,
        worker: "Worker2",
        state: "completed",
        queue: "searching",
        attempt: 1,
        inserted_at: ~N[2026-01-01 00:00:00],
        attempted_at: ~N[2026-01-01 00:00:02],
        scheduled_at: ~N[2026-01-01 00:00:00]
      ),
      build(:job,
        id: 3,
        worker: "Worker3",
        state: "retryable",
        queue: "matching",
        attempt: 2,
        inserted_at: ~N[2026-01-01 00:00:00],
        attempted_at: ~N[2026-01-01 00:00:03],
        scheduled_at: ~N[2026-01-01 00:00:00]
      )
    ]
  end
end
