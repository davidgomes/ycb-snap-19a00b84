defmodule Factory do
  use ExMachina.Ecto

  def queue_factory(attrs) do
    Map.new(attrs)
  end

  def job_factory(attrs) do
    %{
      id: sequence(:job_id, & &1),
      worker: "MyApp.Worker",
      state: "available",
      queue: "default",
      attempt: 0,
      inserted_at: ~U[2024-01-01 00:00:00Z]
    }
    |> Map.merge(Map.new(attrs))
  end
end
