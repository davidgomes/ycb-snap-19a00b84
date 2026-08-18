defmodule Factory do
  use ExMachina.Ecto

  def queue_factory(attrs) do
    Map.new(attrs)
  end

  def job_factory(attrs) do
    now = DateTime.utc_now()

    %{
      id: sequence(:id, & &1),
      worker: "MyApp.Workers.Default",
      state: "available",
      queue: "default",
      attempt: 0,
      inserted_at: now,
      attempted_at: nil,
      scheduled_at: now
    }
    |> Map.merge(Map.new(attrs))
  end
end
