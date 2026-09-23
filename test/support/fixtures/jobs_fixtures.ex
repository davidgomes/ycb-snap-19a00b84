defmodule FreeObanUi.JobsFixtures do
  @moduledoc """
  Test helpers for creating Oban jobs.
  """

  def job_fixture(attrs \\ %{}) do
    {args, attrs} = Map.pop(Map.new(attrs), :args, %{"id" => 1})

    opts = Keyword.merge([worker: "FreeObanUi.FakeWorker", queue: "default"], Keyword.new(attrs))

    args
    |> Oban.Job.new(opts)
    |> FreeObanUi.Repo.insert!()
  end
end
