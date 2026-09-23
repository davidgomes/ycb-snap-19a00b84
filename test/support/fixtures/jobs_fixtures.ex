defmodule FreeObanUi.JobsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  Oban jobs in any state.
  """

  @doc """
  Inserts a job without executing it.

  Accepts any `Oban.Job.new/2` option, including `:state`.
  """
  def job_fixture(args \\ %{}, opts \\ []) do
    args
    |> Oban.Job.new(Keyword.put_new(opts, :worker, "FreeObanUi.FakeWorker"))
    |> FreeObanUi.Repo.insert!()
  end
end
