defmodule Factory do
  use ExMachina.Ecto

  def queue_factory(attrs) do
    Map.new(attrs)
  end

  def job_factory(attrs) do
    %Oban.Job{
      id: sequence(:job_id, & &1),
      worker: "MyApp.Workers.DefaultWorker",
      state: "available",
      queue: "default",
      args: %{},
      attempt: 0,
      max_attempts: 20,
      inserted_at: ~U[2024-01-01 10:00:00Z],
      scheduled_at: ~U[2024-01-01 10:00:00Z]
    }
    |> merge_attributes(attrs)
  end
end
