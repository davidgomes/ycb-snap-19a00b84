defmodule FreeObanUi.JobsTest do
  use FreeObanUi.DataCase, async: true

  import FreeObanUi.JobsFixtures

  alias FreeObanUi.Jobs

  describe "list_jobs/1" do
    test "returns jobs newest first" do
      first = job_fixture()
      second = job_fixture()

      assert [%{id: id2}, %{id: id1}] = Jobs.list_jobs()
      assert {id1, id2} == {first.id, second.id}
    end

    test "filters by state and queue" do
      available = job_fixture(state: "available", queue: "default")
      completed = job_fixture(state: "completed", queue: "default")
      mailer = job_fixture(state: "completed", queue: "mailers")

      assert [%{id: id}] = Jobs.list_jobs(state: "available")
      assert id == available.id

      assert [%{id: id}] = Jobs.list_jobs(queue: "mailers")
      assert id == mailer.id

      assert [%{id: id}] = Jobs.list_jobs(state: "completed", queue: "default")
      assert id == completed.id
    end

    test "ignores unknown states and blank queues" do
      job_fixture()

      assert [_] = Jobs.list_jobs(state: "bogus", queue: "")
    end

    test "respects the limit" do
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

  test "list_queues/0 returns distinct sorted queues" do
    job_fixture(queue: "mailers")
    job_fixture(queue: "default")
    job_fixture(queue: "mailers")

    assert Jobs.list_queues() == ["default", "mailers"]
  end

  test "retry_job/1 makes a discarded job available" do
    job = job_fixture(state: "discarded")

    assert :ok = Jobs.retry_job(job)
    assert Jobs.get_job(job.id).state == "available"
  end

  test "cancel_job/1 cancels a scheduled job" do
    job = job_fixture(state: "scheduled")

    assert :ok = Jobs.cancel_job(job)
    assert Jobs.get_job(job.id).state == "cancelled"
  end

  test "delete_job/1 removes the job" do
    job = job_fixture(state: "completed")

    assert :ok = Jobs.delete_job(job)
    assert Jobs.get_job(job.id) == nil
  end
end
