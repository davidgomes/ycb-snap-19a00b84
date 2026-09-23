defmodule FreeObanUi.JobsTest do
  use FreeObanUi.DataCase, async: true

  import FreeObanUi.JobsFixtures

  alias FreeObanUi.Jobs

  describe "list_jobs/1" do
    test "returns jobs newest first" do
      first = job_fixture()
      second = job_fixture()

      assert [%{id: id_a}, %{id: id_b}] = Jobs.list_jobs()
      assert [id_a, id_b] == [second.id, first.id]
    end

    test "filters by state" do
      job_fixture(state: "available")
      completed = job_fixture(state: "completed", completed_at: DateTime.utc_now())

      assert [%{id: id}] = Jobs.list_jobs(state: "completed")
      assert id == completed.id
    end

    test "limits the number of jobs" do
      for _ <- 1..3, do: job_fixture()

      assert length(Jobs.list_jobs(limit: 2)) == 2
    end
  end

  test "count_by_state/0 counts jobs in every state" do
    job_fixture(state: "available")
    job_fixture(state: "available")
    job_fixture(state: "discarded")

    counts = Jobs.count_by_state()

    assert counts["available"] == 2
    assert counts["discarded"] == 1
    assert counts["completed"] == 0
    assert Map.keys(counts) |> Enum.sort() == Enum.sort(Jobs.states())
  end

  test "get_job/1 returns the job or nil" do
    job = job_fixture()

    assert Jobs.get_job(job.id).id == job.id
    assert Jobs.get_job(-1) == nil
  end

  test "cancel_job/1 cancels the job" do
    job = job_fixture(state: "available")

    assert Jobs.cancellable?(job)
    assert :ok = Jobs.cancel_job(job)
    assert %{state: "cancelled"} = Jobs.get_job(job.id)
  end

  test "retry_job/1 makes the job available" do
    job = job_fixture(state: "discarded", discarded_at: DateTime.utc_now())

    assert Jobs.retryable?(job)
    assert :ok = Jobs.retry_job(job)
    assert %{state: "available"} = Jobs.get_job(job.id)
  end

  test "delete_job/1 deletes the job" do
    job = job_fixture(state: "completed", completed_at: DateTime.utc_now())

    assert Jobs.deletable?(job)
    assert {:ok, _job} = Jobs.delete_job(job)
    assert Jobs.get_job(job.id) == nil
  end

  test "action predicates follow the job state" do
    executing = job_fixture(state: "executing", attempted_at: DateTime.utc_now())
    completed = job_fixture(state: "completed", completed_at: DateTime.utc_now())

    assert Jobs.cancellable?(executing)
    refute Jobs.retryable?(executing)
    refute Jobs.deletable?(executing)

    refute Jobs.cancellable?(completed)
    assert Jobs.retryable?(completed)
  end
end
