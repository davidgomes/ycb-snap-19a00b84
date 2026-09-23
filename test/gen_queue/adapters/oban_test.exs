defmodule GenQueue.Adapters.ObanTest do
  use ExUnit.Case, async: false

  import Ecto.Query

  alias GenQueueOban.Test.{Enqueuer, Job, Repo}

  setup do
    Repo.delete_all(Oban.Job)
    :ok
  end

  defp inserted_job do
    Oban.Job
    |> order_by(desc: :id)
    |> limit(1)
    |> Repo.one!()
  end

  describe "push/2" do
    test "enqueues a module with empty args to the worker queue" do
      assert {:ok, %GenQueue.Job{module: Job, args: []}} = Enqueuer.push(Job)
      assert %Oban.Job{args: %{}, queue: "events", max_attempts: 10} = inserted_job()
      assert inserted_job().worker == inspect(Job)
    end

    test "enqueues a single-element tuple with empty args" do
      assert {:ok, _} = Enqueuer.push({Job})
      assert %Oban.Job{args: %{}, queue: "events"} = inserted_job()
    end

    test "enqueues a map arg" do
      assert {:ok, _} = Enqueuer.push({Job, %{"foo" => "bar"}})
      assert %Oban.Job{args: %{"foo" => "bar"}} = inserted_job()
    end

    test "enqueues an empty list of args as an empty map" do
      assert {:ok, _} = Enqueuer.push({Job, []})
      assert %Oban.Job{args: %{}} = inserted_job()
    end

    test "enqueues a list containing a single map arg" do
      assert {:ok, _} = Enqueuer.push({Job, [%{"foo" => "bar"}]})
      assert %Oban.Job{args: %{"foo" => "bar"}} = inserted_job()
    end

    test "enqueues to the queue provided" do
      assert {:ok, _} = Enqueuer.push({Job, %{"foo" => "bar"}}, queue: "foo")
      assert %Oban.Job{queue: "foo"} = inserted_job()

      assert {:ok, _} = Enqueuer.push(Job, queue: :bar)
      assert %Oban.Job{queue: "bar"} = inserted_job()
    end

    test "schedules a job with a millisecond delay" do
      now = DateTime.utc_now()

      assert {:ok, _} = Enqueuer.push({Job, %{"foo" => "bar"}}, delay: 10_000)
      assert %Oban.Job{state: "scheduled", scheduled_at: scheduled_at} = inserted_job()
      assert_in_delta DateTime.diff(scheduled_at, now), 10, 1
    end

    test "schedules a job at a specific time" do
      at = DateTime.utc_now() |> DateTime.add(3600) |> DateTime.truncate(:second)

      assert {:ok, _} = Enqueuer.push({Job, %{"foo" => "bar"}}, delay: at)
      assert %Oban.Job{state: "scheduled", scheduled_at: scheduled_at} = inserted_job()
      assert DateTime.compare(DateTime.truncate(scheduled_at, :second), at) == :eq
    end

    test "passes config through as worker options" do
      assert {:ok, _} = Enqueuer.push(Job, config: [priority: 2, max_attempts: 3])
      assert %Oban.Job{priority: 2, max_attempts: 3} = inserted_job()
    end

    test "returns an error for args that are not a map" do
      assert {:error, :invalid_args} = Enqueuer.push({Job, ["foo", "bar"]})
      assert {:error, :invalid_args} = Enqueuer.push({Job, "foo"})
      assert Repo.aggregate(Oban.Job, :count, :id) == 0
    end

    test "returns the changeset error for invalid worker options" do
      assert {:error, %Ecto.Changeset{valid?: false}} =
               Enqueuer.push(Job, config: [max_attempts: 0])
    end
  end
end
