defmodule FreeObanUi.JobsTest do
  use FreeObanUi.DataCase, async: true

  import FreeObanUi.JobsFixtures

  alias FreeObanUi.Jobs

  describe "list_jobs/1" do
    test "returns jobs newest first" do
      older = job_fixture()
      newer = job_fixture()

      assert Enum.map(Jobs.list_jobs(), & &1.id) == [newer.id, older.id]
    end

    test "filters jobs by state" do
      completed = job_fixture(%{}, state: "completed")
      _discarded = job_fixture(%{}, state: "discarded")

      assert [%{id: id}] = Jobs.list_jobs(state: "completed")
      assert id == completed.id
      assert Jobs.list_jobs(state: "executing") == []
    end

    test "returns at most :limit jobs" do
      for _ <- 1..3, do: job_fixture()

      assert length(Jobs.list_jobs(limit: 2)) == 2
    end
  end

  describe "count_jobs_by_state/0" do
    test "counts jobs in every state" do
      job_fixture(%{}, state: "completed")
      job_fixture(%{}, state: "completed")
      job_fixture(%{}, state: "retryable")

      assert Jobs.count_jobs_by_state() == %{
               "executing" => 0,
               "available" => 0,
               "scheduled" => 0,
               "retryable" => 1,
               "cancelled" => 0,
               "discarded" => 0,
               "completed" => 2
             }
    end
  end

  describe "get_job/1 and get_job!/1" do
    test "return the job with the given id" do
      job = job_fixture(%{"id" => 1})

      assert %Oban.Job{args: %{"id" => 1}} = Jobs.get_job(job.id)
      assert %Oban.Job{args: %{"id" => 1}} = Jobs.get_job!(job.id)
    end

    test "handle missing jobs" do
      assert Jobs.get_job(0) == nil
      assert_raise Ecto.NoResultsError, fn -> Jobs.get_job!(0) end
    end
  end

  describe "retry_job/1" do
    test "makes an exhausted job available with an extra attempt" do
      job =
        job_fixture(%{},
          state: "discarded",
          attempt: 3,
          max_attempts: 3,
          discarded_at: DateTime.utc_now()
        )

      assert :ok = Jobs.retry_job(job)
      assert %{state: "available", max_attempts: 4, discarded_at: nil} = Jobs.get_job!(job.id)
    end
  end

  describe "cancel_job/1" do
    test "cancels a scheduled job" do
      job = job_fixture(%{}, schedule_in: 60)

      assert :ok = Jobs.cancel_job(job)
      assert %{state: "cancelled", cancelled_at: %DateTime{}} = Jobs.get_job!(job.id)
    end

    test "leaves completed jobs alone" do
      job = job_fixture(%{}, state: "completed")

      assert :ok = Jobs.cancel_job(job)
      assert %{state: "completed"} = Jobs.get_job!(job.id)
    end
  end

  describe "delete_job/1" do
    test "deletes the job" do
      job = job_fixture(%{}, state: "completed")

      assert :ok = Jobs.delete_job(job)
      assert Jobs.get_job(job.id) == nil
    end

    test "leaves executing jobs alone" do
      job = job_fixture(%{}, state: "executing")

      assert :ok = Jobs.delete_job(job)
      assert %{state: "executing"} = Jobs.get_job!(job.id)
    end
  end

  describe "can_retry?/1, can_cancel?/1 and can_delete?/1" do
    test "reflect which actions apply to each state" do
      actions =
        Map.new(Jobs.states(), fn state ->
          job = %Oban.Job{state: state}
          {state, {Jobs.can_retry?(job), Jobs.can_cancel?(job), Jobs.can_delete?(job)}}
        end)

      assert actions == %{
               "executing" => {false, true, false},
               "available" => {false, true, true},
               "scheduled" => {true, true, true},
               "retryable" => {true, true, true},
               "cancelled" => {true, false, true},
               "discarded" => {true, false, true},
               "completed" => {true, false, true}
             }
    end
  end
end
