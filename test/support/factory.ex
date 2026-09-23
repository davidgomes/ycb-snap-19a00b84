defmodule Factory do
  use ExMachina.Ecto

  def queue_factory(attrs) do
    Map.new(attrs)
  end

  def job_factory(attrs) do
    Map.merge(
      %{
        id: sequence(:job_id, & &1),
        worker: "MyApp.Worker",
        state: "available",
        queue: "default",
        attempt: 0,
        inserted_at: ~N[2024-01-01 00:00:00],
        attempted_at: nil,
        scheduled_at: ~N[2024-01-01 00:00:00]
      },
      Map.new(attrs)
    )
  end
end
