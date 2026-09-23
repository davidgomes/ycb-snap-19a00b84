defmodule FreeObanUi.JobsFixtures do
  @moduledoc """
  This module defines test helpers for creating Oban jobs.
  """

  @doc """
  Inserts a job directly into the database, so it can be given any state.
  """
  def job_fixture(attrs \\ %{}) do
    %Oban.Job{worker: "FreeObanUi.ExampleWorker", args: %{"id" => 1}}
    |> struct!(attrs)
    |> FreeObanUi.Repo.insert!()
  end
end
