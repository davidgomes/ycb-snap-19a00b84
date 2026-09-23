defmodule GenQueue.Adapters.ObanTest do
  use ExUnit.Case

  alias GenQueue.Oban.Test.{Enqueuer, Job, Repo}

  setup do
    Repo.delete_all(Oban.Job)
    :ok
  end

  describe "push/2" do
    test "enqueues a module with empty args" do
      assert {:ok, %GenQueue.Job{module: Job, args: []}} = Enqueuer.push(Job)
      assert %Oban.Job{args: %{}, queue: "events", worker: "GenQueue.Oban.Test.Job"} = inserted()
    end

    test "enqueues a single element tuple with empty args" do
      assert {:ok, %GenQueue.Job{module: Job, args: []}} = Enqueuer.push({Job})
      assert %Oban.Job{args: %{}, queue: "events"} = inserted()
    end

    test "enqueues a module with a map arg" do
      assert {:ok, %GenQueue.Job{args: [%{"foo" => "bar"}]}} =
               Enqueuer.push({Job, %{"foo" => "bar"}})

      assert %Oban.Job{args: %{"foo" => "bar"}, queue: "events"} = inserted()
    end

    test "enqueues a module with an empty args list" do
      assert {:ok, %GenQueue.Job{args: []}} = Enqueuer.push({Job, []})
      assert %Oban.Job{args: %{}, queue: "events"} = inserted()
    end

    test "enqueues a module with a single map in the args list" do
      assert {:ok, %GenQueue.Job{args: [%{"foo" => "bar"}]}} =
               Enqueuer.push({Job, [%{"foo" => "bar"}]})

      assert %Oban.Job{args: %{"foo" => "bar"}} = inserted()
    end

    test "enqueues to a specific queue" do
      assert {:ok, %GenQueue.Job{queue: "foo"}} =
               Enqueuer.push({Job, %{"foo" => "bar"}}, queue: "foo")

      assert %Oban.Job{args: %{"foo" => "bar"}, queue: "foo", state: "available"} = inserted()
    end

    test "schedules a job with a millisecond delay" do
      before = DateTime.utc_now()

      assert {:ok, %GenQueue.Job{delay: 10_000}} =
               Enqueuer.push({Job, %{"foo" => "bar"}}, delay: 10_000)

      assert %Oban.Job{state: "scheduled", scheduled_at: scheduled_at} = inserted()
      assert DateTime.diff(scheduled_at, before, :millisecond) >= 10_000
      assert DateTime.diff(scheduled_at, DateTime.utc_now(), :millisecond) <= 10_000
    end

    test "schedules a job at a specific time" do
      date = DateTime.add(DateTime.utc_now(), 60, :second)

      assert {:ok, %GenQueue.Job{delay: ^date}} =
               Enqueuer.push({Job, %{"foo" => "bar"}}, delay: date)

      assert %Oban.Job{state: "scheduled", scheduled_at: ^date} = inserted()
    end

    test "returns an error when given multiple args" do
      assert {:error, {:invalid_args, [1, 2]}} = Enqueuer.push({Job, [1, 2]})
      assert Repo.aggregate(Oban.Job, :count, :id) == 0
    end

    test "returns an error when given a non-map arg" do
      assert {:error, {:invalid_args, ["foo"]}} = Enqueuer.push({Job, "foo"})
      assert Repo.aggregate(Oban.Job, :count, :id) == 0
    end

    test "enqueued jobs are performed by oban" do
      Process.register(self(), Job.receiver())

      assert {:ok, _} = Enqueuer.push({Job, %{"foo" => "bar"}})
      assert_receive {:performed, %{"foo" => "bar"}}
    end
  end

  defp inserted do
    Repo.one!(Oban.Job)
  end
end
