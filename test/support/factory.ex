defmodule Factory do
  use ExMachina.Ecto

  def queue_factory(attrs) do
    Map.new(attrs)
  end

  def job_factory do
    %Oban.Job{
      id: sequence(:job_id, & &1),
      worker: "MyApp.Worker",
      state: "available",
      queue: "default",
      attempt: 0,
      args: %{},
      inserted_at: ~U[2024-01-01 10:00:00.000000Z],
      scheduled_at: ~U[2024-01-01 10:00:00.000000Z],
      attempted_at: nil
    }
  end
end
