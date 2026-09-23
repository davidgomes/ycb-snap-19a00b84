defmodule EctoJob.SupervisorTest do
  use ExUnit.Case
  alias EctoJob.Test.JobQueue

  test "start_link" do
    {:ok, pid} = JobQueue.start_link(repo: EctoJob.Test.Repo, max_demand: 25)

    assert [
             {EctoJob.WorkerSupervisor, _, :supervisor, [EctoJob.WorkerSupervisor]},
             {EctoJob.Producer, producer_pid, :worker, [EctoJob.Producer]}
             | notifier_children
           ] = Supervisor.which_children(pid)

    assert Process.whereis(JobQueue.Supervisor) == pid
    assert Process.whereis(JobQueue.Producer) == producer_pid
    assert_notifier(EctoJob.Test.Repo.__adapter__(), notifier_children)
  end

  defp assert_notifier(Ecto.Adapters.Postgres, notifier_children) do
    assert [{Postgrex.Notifications, notifications_pid, :worker, [Postgrex.Notifications]}] =
             notifier_children

    assert Process.whereis(JobQueue.Notifier) == notifications_pid
  end

  defp assert_notifier(Ecto.Adapters.MyXQL, notifier_children) do
    assert notifier_children == []
    assert Process.whereis(JobQueue.Notifier) == nil
  end
end
