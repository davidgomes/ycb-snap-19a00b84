defmodule GenQueue.Adapters.ObanTest do
  use ExUnit.Case

  alias GenQueueOban.Test.{Enqueuer, Repo, Worker}

  setup do
    Repo.delete_all(Oban.Job)
    :ok
  end

  describe "push/2" do
    test "pushes a job with no args" do
      assert {:ok, %GenQueue.Job{module: Worker, args: []}} = Enqueuer.push(Worker)
      assert %Oban.Job{worker: "GenQueueOban.Test.Worker", args: %{}} = pushed_job()
    end

    test "pushes a job given as a tuple with no args" do
      assert {:ok, %GenQueue.Job{}} = Enqueuer.push({Worker})
      assert %Oban.Job{args: %{}} = pushed_job()
    end

    test "pushes a job given a map of args" do
      assert {:ok, %GenQueue.Job{}} = Enqueuer.push({Worker, %{"foo" => "bar"}})
      assert %Oban.Job{args: %{"foo" => "bar"}} = pushed_job()
    end

    test "pushes a job given an empty list of args" do
      assert {:ok, %GenQueue.Job{}} = Enqueuer.push({Worker, []})
      assert %Oban.Job{args: %{}} = pushed_job()
    end

    test "pushes a job given a list with a map of args" do
      assert {:ok, %GenQueue.Job{}} = Enqueuer.push({Worker, [%{"foo" => "bar"}]})
      assert %Oban.Job{args: %{"foo" => "bar"}} = pushed_job()
    end

    test "pushes a job to the queue of the worker" do
      assert {:ok, %GenQueue.Job{}} = Enqueuer.push(Worker)
      assert %Oban.Job{queue: "default", state: "available"} = pushed_job()
    end

    test "pushes a job to a given queue" do
      assert {:ok, %GenQueue.Job{}} = Enqueuer.push(Worker, queue: "foo")
      assert %Oban.Job{queue: "foo"} = pushed_job()
    end

    test "pushes a job with additional job config" do
      assert {:ok, %GenQueue.Job{}} = Enqueuer.push(Worker, config: [max_attempts: 5])
      assert %Oban.Job{max_attempts: 5} = pushed_job()
    end

    test "schedules a job with a delay in milliseconds" do
      assert {:ok, %GenQueue.Job{}} = Enqueuer.push(Worker, delay: 10_000)
      assert %Oban.Job{state: "scheduled", scheduled_at: scheduled_at} = pushed_job()
      assert_in_delta DateTime.diff(scheduled_at, DateTime.utc_now()), 10, 1
    end

    test "schedules a job with a delay as a datetime" do
      date = DateTime.add(DateTime.utc_now(), 60)

      assert {:ok, %GenQueue.Job{}} = Enqueuer.push(Worker, delay: date)
      assert %Oban.Job{state: "scheduled", scheduled_at: scheduled_at} = pushed_job()
      assert_in_delta DateTime.diff(scheduled_at, date), 0, 1
    end

    test "returns an error with an invalid job" do
      assert {:error, %Ecto.Changeset{}} = Enqueuer.push(Worker, config: [max_attempts: 0])
      refute pushed_job()
    end

    test "raises with args that cannot be pushed to Oban" do
      assert_raise ArgumentError, fn -> Enqueuer.push({Worker, ["foo", "bar"]}) end
    end
  end

  defp pushed_job do
    Repo.one(Oban.Job)
  end
end
