defmodule FreeObanUi.JobsTest do
  use FreeObanUi.DataCase

  alias FreeObanUi.Jobs
  alias FreeObanUi.Workers.ExampleWorker

  describe "jobs context" do
    test "list_queues/0 returns configured and db queues" do
      queues = Jobs.list_queues()
      assert "default" in queues
      assert "events" in queues
      assert "mailers" in queues
    end

    test "count_jobs_by_state/1 and list_jobs/1" do
      {:ok, job1} =
        %{action: "test1"}
        |> ExampleWorker.new(queue: :default)
        |> Oban.insert()

      {:ok, job2} =
        %{action: "test2"}
        |> ExampleWorker.new(queue: :events, schedule_in: 300)
        |> Oban.insert()

      counts = Jobs.count_jobs_by_state()
      assert counts["all"] >= 2
      assert counts["available"] >= 1
      assert counts["scheduled"] >= 1

      jobs = Jobs.list_jobs(%{"queue" => "default"})
      assert Enum.any?(jobs, &(&1.id == job1.id))

      jobs_events = Jobs.list_jobs(%{"queue" => "events"})
      assert Enum.any?(jobs_events, &(&1.id == job2.id))

      assert Jobs.count_jobs(%{"queue" => "default"}) >= 1
    end

    test "get_job/1 and get_job!/1" do
      {:ok, job} =
        %{action: "find_me"}
        |> ExampleWorker.new()
        |> Oban.insert()

      assert Jobs.get_job(job.id).id == job.id
      assert Jobs.get_job!(job.id).id == job.id
      assert is_nil(Jobs.get_job(-1))
    end

    test "retry_job/1, cancel_job/1, delete_job/1" do
      {:ok, job} =
        %{action: "to_cancel"}
        |> ExampleWorker.new()
        |> Oban.insert()

      assert :ok = Jobs.cancel_job(job.id)
      cancelled_job = Jobs.get_job(job.id)
      assert cancelled_job.state == "cancelled"

      assert :ok = Jobs.retry_job(job.id)
      retried_job = Jobs.get_job(job.id)
      assert retried_job.state == "available"

      assert {:ok, _} = Jobs.delete_job(job.id)
      assert is_nil(Jobs.get_job(job.id))
    end

    test "retry_all/1 and cancel_all/1" do
      {:ok, job1} =
        %{action: "bulk_1"}
        |> ExampleWorker.new(queue: :default)
        |> Oban.insert()

      {:ok, _job2} =
        %{action: "bulk_2"}
        |> ExampleWorker.new(queue: :default)
        |> Oban.insert()

      {:ok, count} = Jobs.cancel_all(%{"queue" => "default"})
      assert count >= 2

      job1_after = Jobs.get_job(job1.id)
      assert job1_after.state == "cancelled"

      {:ok, retry_count} = Jobs.retry_all(%{"queue" => "default"})
      assert retry_count >= 2

      job1_retried = Jobs.get_job(job1.id)
      assert job1_retried.state == "available"
    end
  end
end
