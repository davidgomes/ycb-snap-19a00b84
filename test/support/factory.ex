defmodule Factory do
  use ExMachina.Ecto

  def queue_factory(attrs) do
    Map.new(attrs)
  end

  def job_factory do
    %Oban.Job{
      id: sequence(:job_id, &(&1 + 1)),
      worker: "MyApp.Workers.Mailer",
      inserted_at: DateTime.utc_now(),
      scheduled_at: DateTime.utc_now()
    }
  end
end
