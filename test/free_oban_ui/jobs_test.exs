defmodule FreeObanUi.JobsTest do
  use FreeObanUi.DataCase

  import FreeObanUi.JobsFixtures

  alias FreeObanUi.Jobs

  describe "list_jobs/1" do
    test "returns jobs newest first" do
      first = job_fixture()
      second = job_fixture()

      assert [%{id: id2}, %{id: id1}] = Jobs.list_jobs()
      assert id1 == first.id
      assert id2 == second.id
    end

    test "filters by state, queue and worker" do
      completed = job_fixture(%{state: "completed", queue: "mailers", worker: "MyApp.Mailer"})
      _available = job_fixture(%{state: "available", queue: "default"})

      assert [%{id: id}] = Jobs.list_jobs(state: "completed")
      assert id == completed.id
      assert [%{id: ^id}] = Jobs.list_jobs(queue: "mailers")
      assert [%{id: ^id}] = Jobs.list_jobs(search: "mailer")
      assert [] = Jobs.list_jobs(search: "%nomatch%")
    end

    test "ignores unknown states" do
      job_fixture()

      assert [_] = Jobs.list_jobs(state: "bogus")
    end
  end

  test "count_by_state/1 includes every state" do
    job_fixture(%{state: "completed"})
    job_fixture(%{state: "completed"})
    job_fixture(%{state: "discarded", queue: "other"})

    counts = Jobs.count_by_state()
    assert counts["completed"] == 2
    assert counts["discarded"] == 1
    assert counts["available"] == 0
    assert Map.keys(counts) |> Enum.sort() == Enum.sort(Jobs.states())

    assert %{"completed" => 0, "discarded" => 1} = Jobs.count_by_state(queue: "other")
  end

  test "list_queues/0 returns distinct queues" do
    job_fixture(%{queue: "b"})
    job_fixture(%{queue: "a"})
    job_fixture(%{queue: "a"})

    assert Jobs.list_queues() == ["a", "b"]
  end

  describe "actions" do
    test "retry_job/1 makes a discarded job available again" do
      job = job_fixture(%{state: "discarded", attempt: 3, max_attempts: 3})

      assert :ok = Jobs.retry_job(job)
      assert %{state: "available"} = Jobs.get_job(job.id)
    end

    test "cancel_job/1 cancels an available job" do
      job = job_fixture()

      assert :ok = Jobs.cancel_job(job)
      assert %{state: "cancelled"} = Jobs.get_job(job.id)
    end

    test "delete_job/1 removes the job" do
      job = job_fixture()

      assert :ok = Jobs.delete_job(job)
      assert Jobs.get_job(job.id) == nil
    end
  end
end
