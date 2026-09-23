defmodule ObanChore.DataCase do
  @moduledoc """
  Test case for tests that need the database, the `Oban` instance started in
  `test_helper.exs`, and the shared `ObanChore.TestPubSub` server.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      use Oban.Testing, repo: ObanChore.TestRepo

      import ObanChore.DataCase
    end
  end

  setup tags do
    setup_sandbox(tags)
    :ok
  end

  @doc """
  Checks out a sandboxed connection, shared with every process when the test isn't async.
  """
  def setup_sandbox(tags) do
    pid = Sandbox.start_owner!(ObanChore.TestRepo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
  end

  @doc """
  Inserts a job for `worker` with `args`, forcing it into `state`.
  """
  def insert_job!(worker, args, state \\ "available") do
    args
    |> worker.new()
    |> Ecto.Changeset.put_change(:state, state)
    |> Oban.insert!()
  end

  @doc """
  Performs a job inserted with `insert_job!/3` as if a queue had fetched it, emitting
  Oban's job telemetry events.
  """
  def execute_job(job) do
    job = ObanChore.TestRepo.reload!(job)

    %{job | state: "executing", attempt: 1, attempted_at: DateTime.utc_now()}
    |> Oban.Testing.perform_job(repo: ObanChore.TestRepo)
  end
end
