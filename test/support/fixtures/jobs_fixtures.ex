defmodule FreeObanUi.JobsFixtures do
  @moduledoc """
  Test helpers for inserting `Oban.Job` records.
  """

  @doc """
  Inserts a job. Accepts any `Oban.Job.new/2` option plus `:args`.
  """
  def job_fixture(opts \\ []) do
    {args, opts} = Keyword.pop(opts, :args, %{"id" => 1})

    args
    |> Oban.Job.new(Keyword.merge([worker: "MyApp.FakeWorker", queue: "default"], opts))
    |> FreeObanUi.Repo.insert!()
  end
end
