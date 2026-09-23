defmodule FreeObanUi.JobsFixtures do
  @moduledoc """
  Test helpers for inserting Oban jobs directly, in any state.
  """

  def job_fixture(attrs \\ %{}) do
    {args, opts} = attrs |> Map.new() |> Map.pop(:args, %{"id" => 1})

    opts = Keyword.merge([worker: "FreeObanUi.FakeWorker", queue: "default"], Map.to_list(opts))

    args
    |> Oban.Job.new(opts)
    |> FreeObanUi.Repo.insert!()
  end
end
