defmodule FreeObanUi.JobsTest do
  use FreeObanUi.DataCase, async: true

  import FreeObanUi.JobsFixtures

  alias FreeObanUi.Jobs

  describe "list_jobs/1" do
    test "returns jobs newest first" do
      older = job_fixture()
      newer = job_fixture()

      assert [newer.id, older.id] == Enum.map(Jobs.list_jobs(), & &1.id)
    end

    test "filters by state" do
      completed = job_fixture(state: "completed")
      _available = job_fixture(state: "available")

      assert [%{id: id}] = Jobs.list_jobs(state: "completed")
      assert id == completed.id
    end

    test "limits the number of results" do
      for _ <- 1..3, do: job_fixture()

      assert length(Jobs.list_jobs(limit: 2)) == 2
    end
  end

  test "count_by_state/0 includes every state" do
    job_fixture(state: "completed")
    job_fixture(state: "completed")
    job_fixture(state: "discarded")

    counts = Jobs.count_by_state()

    assert Map.keys(counts) |> Enum.sort() == Enum.sort(Jobs.states())
    assert counts["completed"] == 2
    assert counts["discarded"] == 1
    assert counts["available"] == 0
  end

  test "retry_job/1 makes the job available again" do
    job = job_fixture(state: "discarded", attempt: 20, max_attempts: 20)

    assert :ok = Jobs.retry_job(job)
    assert %{state: "available"} = Jobs.get_job!(job.id)
  end

  test "cancel_job/1 cancels the job" do
    job = job_fixture(state: "scheduled")

    assert :ok = Jobs.cancel_job(job)
    assert %{state: "cancelled"} = Jobs.get_job!(job.id)
  end

  describe "delete_job/1" do
    test "deletes the job" do
      job = job_fixture(state: "completed")

      assert :ok = Jobs.delete_job(job)
      refute Jobs.get_job(job.id)
    end

    test "does not delete executing jobs" do
      job = job_fixture(state: "executing")

      assert :ok = Jobs.delete_job(job)
      assert Jobs.get_job(job.id)
    end
  end

  test "action predicates follow the job state" do
    assert Jobs.retryable?(%Oban.Job{state: "discarded"})
    refute Jobs.retryable?(%Oban.Job{state: "executing"})

    assert Jobs.cancellable?(%Oban.Job{state: "scheduled"})
    refute Jobs.cancellable?(%Oban.Job{state: "completed"})

    assert Jobs.deletable?(%Oban.Job{state: "completed"})
    refute Jobs.deletable?(%Oban.Job{state: "executing"})
  end
end
