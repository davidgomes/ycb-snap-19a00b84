defmodule ObanChore.ObanCase do
  @moduledoc """
  Case template for tests that run a real Oban instance against the test database.

  Jobs are executed by real queues, so these tests can't run concurrently and
  the jobs table is cleared before each test instead of using the SQL sandbox.
  """
  use ExUnit.CaseTemplate

  import Ecto.Query, only: [where: 3, order_by: 2]

  alias ObanChore.Test.Repo

  @pubsub ObanChore.Test.PubSub

  using do
    quote do
      import ObanChore.ObanCase
      alias ObanChore.Test.{Chores, Repo}
    end
  end

  setup do
    Repo.delete_all(Oban.Job)
    ObanChore.Test.Chores.register_runner()
    :ok
  end

  def pubsub, do: @pubsub

  @doc """
  Starts the default `Oban` instance with `ObanChore.Plugin` registering `chores`.
  """
  def start_oban!(chores, opts \\ []) do
    opts =
      Keyword.merge(
        [
          name: Oban,
          repo: Repo,
          queues: [default: 5],
          notifier: Oban.Notifiers.Isolated,
          peer: Oban.Peers.Isolated,
          stage_interval: 100,
          shutdown_grace_period: 0,
          plugins: [{ObanChore.Plugin, pubsub_server: @pubsub, chores: chores}]
        ],
        opts
      )

    pid = start_supervised!({Oban, opts})
    # Discovery and telemetry attachment happen in handle_continue
    _ = :sys.get_state(ObanChore.Plugin)
    pid
  end

  @doc """
  Waits for a job started by a `ObanChore.Test.Chores.checkpoint/1` worker.
  """
  def await_job_started(timeout \\ 2_000) do
    receive do
      {:job_started, job_id, pid} -> {job_id, pid}
    after
      timeout -> flunk("no job started within #{timeout}ms")
    end
  end

  def release_job(pid), do: send(pid, :continue)

  def insert_job!(worker, args), do: worker.new(args) |> Oban.insert!()

  def jobs_for(worker) do
    Oban.Job
    |> where([j], j.worker == ^inspect(worker))
    |> order_by(asc: :id)
    |> Repo.all()
  end
end
