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
      available = job_fixture()
      _completed = job_fixture(state: "completed", completed_at: DateTime.utc_now())

      assert [%{id: id}] = Jobs.list_jobs(state: "available")
      assert id == available.id
    end

    test "respects the limit" do
      for _ <- 1..3, do: job_fixture()

      assert length(Jobs.list_jobs(limit: 2)) == 2
    end
  end

  test "count_jobs_by_state/0 includes every state" do
    job_fixture()
    job_fixture()
    job_fixture(state: "discarded", discarded_at: DateTime.utc_now())

    counts = Jobs.count_jobs_by_state()

    assert Map.keys(counts) |> Enum.sort() == Enum.sort(Jobs.states())
    assert counts["available"] == 2
    assert counts["discarded"] == 1
    assert counts["completed"] == 0
  end

  test "retry_job/1 makes a discarded job available again" do
    job = job_fixture(state: "discarded", discarded_at: DateTime.utc_now(), attempt: 20)

    assert :ok = Jobs.retry_job(job)
    assert %{state: "available"} = Jobs.get_job(job.id)
  end

  test "cancel_job/1 cancels a pending job" do
    job = job_fixture()

    assert :ok = Jobs.cancel_job(job)
    assert %{state: "cancelled", cancelled_at: %DateTime{}} = Jobs.get_job(job.id)
  end

  test "delete_job/1 removes the job" do
    job = job_fixture()

    assert {:ok, _job} = Jobs.delete_job(job)
    assert Jobs.get_job(job.id) == nil
  end

  test "action predicates follow job state" do
    available = %Oban.Job{state: "available"}
    executing = %Oban.Job{state: "executing"}
    completed = %Oban.Job{state: "completed"}

    refute Jobs.retryable?(available)
    refute Jobs.retryable?(executing)
    assert Jobs.retryable?(completed)

    assert Jobs.cancellable?(available)
    assert Jobs.cancellable?(executing)
    refute Jobs.cancellable?(completed)

    assert Jobs.deletable?(available)
    refute Jobs.deletable?(executing)
    assert Jobs.deletable?(completed)
  end
end
