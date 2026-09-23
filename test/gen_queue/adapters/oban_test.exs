defmodule GenQueue.Adapters.ObanTest do
  use ExUnit.Case

  import Ecto.Query

  alias GenQueueOban.{Enqueuer, TestJob, TestRepo}

  defmodule RunningEnqueuer do
    use GenQueue, adapter: GenQueue.Adapters.Oban
  end

  setup do
    TestRepo.delete_all(Oban.Job)
    start_supervised!(Enqueuer)
    :ok
  end

  describe "push/2" do
    test "enqueues a zero-arg module with %{} args to the worker's queue" do
      assert {:ok, %GenQueue.Job{module: TestJob}} = Enqueuer.push(TestJob)
      assert %Oban.Job{args: %{}, queue: "events", state: "available"} = last_job()
    end

    test "enqueues a single element tuple with %{} args" do
      assert {:ok, _} = Enqueuer.push({TestJob})
      assert %Oban.Job{args: %{}} = last_job()
    end

    test "enqueues a map arg" do
      assert {:ok, _} = Enqueuer.push({TestJob, %{"foo" => "bar"}})
      assert %Oban.Job{args: %{"foo" => "bar"}} = last_job()
    end

    test "enqueues an empty arg list with %{} args" do
      assert {:ok, _} = Enqueuer.push({TestJob, []})
      assert %Oban.Job{args: %{}} = last_job()
    end

    test "enqueues a list containing a single map arg" do
      assert {:ok, _} = Enqueuer.push({TestJob, [%{"foo" => "bar"}]})
      assert %Oban.Job{args: %{"foo" => "bar"}} = last_job()
    end

    test "enqueues the worker name" do
      assert {:ok, _} = Enqueuer.push(TestJob)
      assert last_job().worker == "GenQueueOban.TestJob"
    end

    test "enqueues to a given queue" do
      assert {:ok, %GenQueue.Job{queue: "foo"}} = Enqueuer.push(TestJob, queue: "foo")
      assert %Oban.Job{queue: "foo"} = last_job()
    end

    test "schedules a job with an integer delay in milliseconds" do
      assert {:ok, _} = Enqueuer.push(TestJob, delay: 10_000)
      job = last_job()

      assert job.state == "scheduled"
      assert_in_delta NaiveDateTime.diff(job.scheduled_at, NaiveDateTime.utc_now()), 10, 2
    end

    test "schedules a job at a specific time" do
      date = DateTime.add(DateTime.utc_now(), 3600, :second)
      assert {:ok, _} = Enqueuer.push(TestJob, delay: date)
      job = last_job()

      assert job.state == "scheduled"
      assert_in_delta NaiveDateTime.diff(job.scheduled_at, DateTime.to_naive(date)), 0, 1
    end

    test "passes adapter-specific config to the worker" do
      assert {:ok, _} = Enqueuer.push(TestJob)
      assert last_job().max_attempts == 5

      assert {:ok, _} = Enqueuer.push(TestJob, config: [max_attempts: 1])
      assert last_job().max_attempts == 1
    end

    test "returns an error for args that are not a map" do
      assert {:error, :invalid_args} = Enqueuer.push({TestJob, ["foo", "bar"]})
      assert {:error, :invalid_args} = Enqueuer.push({TestJob, "foo"})
      assert TestRepo.aggregate(Oban.Job, :count, :id) == 0
    end
  end

  describe "start_link/2" do
    test "starts an Oban instance that performs pushed jobs" do
      Process.register(self(), :gen_queue_oban_test)

      start_supervised!(
        {RunningEnqueuer, repo: TestRepo, queues: [events: 1], poll_interval: 100}
      )

      assert {:ok, _} = RunningEnqueuer.push({TestJob, %{"foo" => "bar"}})
      assert_receive {:performed, %{"foo" => "bar"}}
    end
  end

  defp last_job do
    Oban.Job
    |> order_by(desc: :id)
    |> limit(1)
    |> TestRepo.one!()
  end
end
