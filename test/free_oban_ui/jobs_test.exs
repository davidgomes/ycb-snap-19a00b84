defmodule FreeObanUi.JobsTest do
  use FreeObanUi.DataCase, async: true

  import FreeObanUi.JobsFixtures

  alias FreeObanUi.Jobs

  describe "list_jobs/1" do
    test "returns the most recently inserted jobs first" do
      first = job_fixture()
      second = job_fixture()

      assert ids(Jobs.list_jobs()) == [second.id, first.id]
    end

    test "filters by state and queue" do
      available = job_fixture(queue: "default")
      completed = job_fixture(queue: "default", state: "completed")
      mailer = job_fixture(queue: "mailers")

      assert ids(Jobs.list_jobs(state: "completed")) == [completed.id]
      assert ids(Jobs.list_jobs(queue: "mailers")) == [mailer.id]
      assert ids(Jobs.list_jobs(state: "available", queue: "default")) == [available.id]

      assert ids(Jobs.list_jobs(state: nil, queue: nil)) ==
               [mailer.id, completed.id, available.id]
    end

    test "limits the number of jobs returned" do
      for _ <- 1..3, do: job_fixture()

      assert length(Jobs.list_jobs(limit: 2)) == 2
    end
  end

  describe "count_jobs_by_state/1" do
    test "counts the jobs in every state" do
      job_fixture()
      job_fixture()
      job_fixture(state: "discarded", queue: "mailers")

      counts = Jobs.count_jobs_by_state()

      assert Enum.sort(Map.keys(counts)) == Enum.sort(Jobs.states())
      assert %{"available" => 2, "discarded" => 1, "executing" => 0} = counts
    end

    test "only counts jobs in the given queue" do
      job_fixture()
      job_fixture(state: "discarded", queue: "mailers")

      assert %{"available" => 0, "discarded" => 1} = Jobs.count_jobs_by_state(queue: "mailers")
    end
  end

  describe "list_queues/0" do
    test "returns each queue with jobs once, sorted by name" do
      job_fixture(queue: "mailers")
      job_fixture(queue: "default")
      job_fixture(queue: "mailers")

      assert Jobs.list_queues() == ["default", "mailers"]
    end
  end

  describe "get_job/1 and get_job!/1" do
    test "return the job with the given id" do
      job = job_fixture()

      assert Jobs.get_job(job.id).id == job.id
      assert Jobs.get_job!(job.id).id == job.id
    end

    test "handle missing jobs" do
      assert Jobs.get_job(-1) == nil
      assert_raise Ecto.NoResultsError, fn -> Jobs.get_job!(-1) end
    end
  end

  describe "retry_job/1" do
    test "makes a discarded job available again" do
      job =
        job_fixture(
          state: "discarded",
          attempt: 20,
          max_attempts: 20,
          discarded_at: DateTime.utc_now()
        )

      assert :ok = Jobs.retry_job(job)
      assert %{state: "available", discarded_at: nil, max_attempts: 21} = Jobs.get_job!(job.id)
    end
  end

  describe "cancel_job/1" do
    test "cancels a scheduled job" do
      job = job_fixture(schedule_in: 60)

      assert job.state == "scheduled"
      assert :ok = Jobs.cancel_job(job)
      assert %{state: "cancelled", cancelled_at: %DateTime{}} = Jobs.get_job!(job.id)
    end
  end

  describe "retryable?/1 and cancellable?/1" do
    test "reflect which actions are allowed for each state" do
      retryable = for state <- Jobs.states(), Jobs.retryable?(%Oban.Job{state: state}), do: state
      cancellable = for state <- Jobs.states(), Jobs.cancellable?(%Oban.Job{state: state}), do: state

      assert retryable == ~w(retryable completed discarded cancelled)
      assert cancellable == ~w(scheduled available executing retryable)
    end
  end

  defp ids(jobs), do: Enum.map(jobs, & &1.id)
end
