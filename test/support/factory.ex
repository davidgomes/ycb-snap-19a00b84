defmodule Factory do
  use ExMachina.Ecto

  def queue_factory(attrs) do
    Map.new(attrs)
  end

  def job_factory(attrs) do
    default = %{
      id: sequence(:job_id, & &1),
      state: "available",
      queue: "default",
      worker: "Worker",
      args: %{},
      errors: [],
      attempt: 0,
      max_attempts: 20,
      inserted_at: DateTime.utc_now(),
      scheduled_at: DateTime.utc_now(),
      attempted_at: nil,
      completed_at: nil,
      discarded_at: nil,
      cancelled_at: nil
    }

    struct(Oban.Job, Map.merge(default, Map.new(attrs)))
  end
end
