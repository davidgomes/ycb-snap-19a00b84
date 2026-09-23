defmodule FreeObanUi.JobsFixtures do
  @moduledoc """
  Test helpers for inserting Oban jobs in arbitrary states.
  """

  def job_fixture(attrs \\ %{}) do
    now = DateTime.utc_now()

    %Oban.Job{
      worker: "FreeObanUi.Workers.ExampleWorker",
      queue: "default",
      args: %{},
      inserted_at: now,
      scheduled_at: now
    }
    |> struct!(attrs)
    |> FreeObanUi.Repo.insert!()
  end
end
