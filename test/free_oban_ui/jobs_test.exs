defmodule FreeObanUi.JobsTest do
  use FreeObanUi.DataCase, async: true

  import FreeObanUi.JobsFixtures

  alias FreeObanUi.Jobs

  defp ids(jobs), do: Enum.map(jobs, & &1.id)

  describe "list_jobs/1" do
    test "returns jobs in every state, newest first" do
      available = job_fixture()
      completed = job_fixture(state: "completed", completed_at: DateTime.utc_now())

      assert ids(Jobs.list_jobs()) == [completed.id, available.id]
    end

    test "filters jobs by state" do
      completed = job_fixture(state: "completed", completed_at: DateTime.utc_now())
      _available = job_fixture()

      assert ids(Jobs.list_jobs(state: "completed")) == [completed.id]
    end

    test "orders pending jobs by when they run next" do
      now = DateTime.utc_now()
      later = job_fixture(state: "scheduled", scheduled_at: DateTime.add(now, 120))
      sooner = job_fixture(state: "scheduled", scheduled_at: DateTime.add(now, 60))

      assert ids(Jobs.list_jobs(state: "scheduled")) == [sooner.id, later.id]
    end

    test "orders finished jobs by most recently finished" do
      now = DateTime.utc_now()
      recent = job_fixture(state: "discarded", discarded_at: now)
      older = job_fixture(state: "discarded", discarded_at: DateTime.add(now, -60))

      assert ids(Jobs.list_jobs(state: "discarded")) == [recent.id, older.id]
    end

    test "paginates with limit and offset" do
      [first, second, third] = for _ <- 1..3, do: job_fixture()

      assert ids(Jobs.list_jobs(limit: 2)) == [third.id, second.id]
      assert ids(Jobs.list_jobs(limit: 2, offset: 2)) == [first.id]
    end
  end

  describe "count_jobs_by_state/0" do
    test "counts jobs for every state" do
      job_fixture()
      job_fixture()
      job_fixture(state: "discarded", discarded_at: DateTime.utc_now())

      counts = Jobs.count_jobs_by_state()

      assert Enum.sort(Map.keys(counts)) == Enum.sort(Jobs.states())
      assert counts["available"] == 2
      assert counts["discarded"] == 1
      assert counts["executing"] == 0
    end
  end

  describe "get_job/1" do
    test "returns the job or nil" do
      job = job_fixture()

      assert Jobs.get_job(job.id).id == job.id
      assert Jobs.get_job(-1) == nil
    end
  end

  describe "retry_job/1" do
    test "makes a discarded job available again" do
      job = job_fixture(state: "discarded", attempt: 20, discarded_at: DateTime.utc_now())

      assert :ok = Jobs.retry_job(job)

      assert %{state: "available", discarded_at: nil, max_attempts: 21} = Jobs.get_job(job.id)
    end

    test "runs a scheduled job immediately" do
      scheduled_at = DateTime.add(DateTime.utc_now(), 3600)
      job = job_fixture(state: "scheduled", scheduled_at: scheduled_at)

      assert :ok = Jobs.retry_job(job)

      assert %{state: "available"} = job = Jobs.get_job(job.id)
      assert DateTime.compare(job.scheduled_at, scheduled_at) == :lt
    end

    test "rejects executing jobs" do
      job = job_fixture(state: "executing", attempt: 1, attempted_at: DateTime.utc_now())

      assert {:error, :invalid_state} = Jobs.retry_job(job)
      assert %{state: "executing"} = Jobs.get_job(job.id)
    end
  end

  describe "cancel_job/1" do
    test "cancels a scheduled job" do
      job = job_fixture(state: "scheduled", scheduled_at: DateTime.add(DateTime.utc_now(), 60))

      assert :ok = Jobs.cancel_job(job)

      assert %{state: "cancelled", cancelled_at: %DateTime{}} = Jobs.get_job(job.id)
    end

    test "rejects completed jobs" do
      job = job_fixture(state: "completed", completed_at: DateTime.utc_now())

      assert {:error, :invalid_state} = Jobs.cancel_job(job)
      assert %{state: "completed"} = Jobs.get_job(job.id)
    end
  end

  describe "delete_job/1" do
    test "deletes the job" do
      job = job_fixture(state: "completed", completed_at: DateTime.utc_now())

      assert :ok = Jobs.delete_job(job)
      assert Jobs.get_job(job.id) == nil
    end

    test "rejects executing jobs" do
      job = job_fixture(state: "executing", attempt: 1, attempted_at: DateTime.utc_now())

      assert {:error, :invalid_state} = Jobs.delete_job(job)
      assert Jobs.get_job(job.id)
    end

    test "rejects jobs that started executing after they were loaded" do
      job = job_fixture()
      Repo.update_all(where(Oban.Job, id: ^job.id), set: [state: "executing", attempt: 1])

      assert {:error, :invalid_state} = Jobs.delete_job(job)
      assert Jobs.get_job(job.id)
    end
  end
end
