defmodule ObanEvents.Test.Repo do
  @moduledoc """
  Minimal test Repo for ObanEvents testing.

  This repo is used for Oban.Testing which requires a repo parameter.
  It supports in-memory job storage for testing in manual mode without PostgreSQL.
  """

  def config, do: [otp_app: :oban_events]
  def default_options(_), do: []
  def get_dynamic_repo, do: __MODULE__
  def put_dynamic_repo(_), do: :ok
  def in_transaction?, do: false
  def transaction(fun, _opts \\ []), do: {:ok, fun.()}
  def rollback(reason), do: throw({:rollback, reason})

  def insert_all(Oban.Job, entries, _opts \\ []) do
    jobs =
      Enum.map(entries, fn entry ->
        id = System.unique_integer([:positive])
        now = DateTime.utc_now()

        recoded_args =
          entry.args
          |> Jason.encode!()
          |> Jason.decode!()

        job_map =
          entry
          |> Map.put_new(:id, id)
          |> Map.put_new(:state, "available")
          |> Map.put_new(:attempt, 0)
          |> Map.put_new(:inserted_at, now)
          |> Map.put_new(:scheduled_at, now)
          |> Map.put(:args, recoded_args)

        struct(Oban.Job, job_map)
      end)

    current_jobs = Process.get(:mock_oban_jobs, [])
    Process.put(:mock_oban_jobs, current_jobs ++ jobs)

    {length(jobs), jobs}
  end

  def all(_query, _opts \\ []) do
    Process.get(:mock_oban_jobs, [])
  end

  def delete_all(_query, _opts \\ []) do
    jobs = Process.get(:mock_oban_jobs, [])
    Process.put(:mock_oban_jobs, [])
    {length(jobs), nil}
  end
end
