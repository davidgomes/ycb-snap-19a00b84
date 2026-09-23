defmodule FreeObanUi.JobsFixtures do
  @moduledoc """
  This module defines test helpers for creating Oban jobs.
  """

  @doc """
  Inserts a job without running it.

  Accepts `:args` along with any option supported by `Oban.Job.new/2`,
  such as `:state`, `:queue` or `:errors`.
  """
  def job_fixture(opts \\ []) do
    {args, opts} = Keyword.pop(opts, :args, %{"id" => 1})

    args
    |> Oban.Job.new(Keyword.put_new(opts, :worker, "FreeObanUi.Workers.ExampleWorker"))
    |> FreeObanUi.Repo.insert!()
  end
end
