defmodule EctoJob.SupervisorTest do
  use ExUnit.Case
  alias EctoJob.Test.{JobQueue, Repo}

  test "start_link" do
    {:ok, pid} = JobQueue.start_link(repo: Repo, max_demand: 25)

    assert [
             {EctoJob.WorkerSupervisor, _, :supervisor, [EctoJob.WorkerSupervisor]},
             {EctoJob.Producer, producer_pid, :worker, [EctoJob.Producer]} | notifiers
           ] = Supervisor.which_children(pid)

    assert Process.whereis(JobQueue.Supervisor) == pid
    assert Process.whereis(JobQueue.Producer) == producer_pid

    case Repo.__adapter__() do
      Ecto.Adapters.Postgres ->
        assert [{Postgrex.Notifications, notifications_pid, :worker, [Postgrex.Notifications]}] =
                 notifiers

        assert Process.whereis(JobQueue.Notifier) == notifications_pid

      Ecto.Adapters.MyXQL ->
        assert notifiers == []
        assert Process.whereis(JobQueue.Notifier) == nil
    end
  end
end
