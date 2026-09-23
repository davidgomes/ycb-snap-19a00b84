defmodule FreeObanUi.JobsFixtures do
  @moduledoc """
  Test helpers for inserting Oban jobs directly into the database.
  """

  alias FreeObanUi.Repo

  def job_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    {state, attrs} = Map.pop(attrs, :state, "available")
    {args, attrs} = Map.pop(attrs, :args, %{})
    opts = attrs |> Map.put_new(:worker, "FreeObanUi.TestWorker") |> Keyword.new()

    args
    |> Oban.Job.new(opts)
    |> Ecto.Changeset.put_change(:state, state)
    |> Repo.insert!()
  end
end
