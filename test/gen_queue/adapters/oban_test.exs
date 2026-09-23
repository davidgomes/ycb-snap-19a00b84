defmodule GenQueue.Adapters.ObanTest do
  use ExUnit.Case

  import GenQueue.Test

  alias GenQueueOban.Test.Repo

  defmodule Enqueuer do
    Application.put_env(:gen_queue_oban, __MODULE__, adapter: GenQueue.Adapters.Oban)

    use GenQueue, otp_app: :gen_queue_oban
  end

  defmodule Job do
    use Oban.Worker, queue: "events"

    @impl Oban.Worker
    def perform(args, job) do
      send_item(Enqueuer, {:performed, args, job.queue})
    end
  end

  setup do
    Repo.delete_all(Oban.Job)
    setup_global_test_queue(Enqueuer, :test)
    start_supervised!({Enqueuer, repo: Repo, queues: [events: 1, foo: 1]})
    :ok
  end

  describe "push/2" do
    test "enqueues and runs job from module" do
      {:ok, job} = Enqueuer.push(Job)
      assert_receive({:performed, args, "events"})
      assert args == %{}
      assert %GenQueue.Job{module: Job, args: []} = job
    end

    test "enqueues and runs job from module tuple" do
      {:ok, job} = Enqueuer.push({Job})
      assert_receive({:performed, args, "events"})
      assert args == %{}
      assert %GenQueue.Job{module: Job, args: []} = job
    end

    test "enqueues and runs job from module and map arg" do
      {:ok, job} = Enqueuer.push({Job, %{"foo" => "bar"}})
      assert_receive({:performed, %{"foo" => "bar"}, "events"})
      assert %GenQueue.Job{module: Job, args: [%{"foo" => "bar"}]} = job
    end

    test "enqueues and runs job from module and empty args" do
      {:ok, job} = Enqueuer.push({Job, []})
      assert_receive({:performed, args, "events"})
      assert args == %{}
      assert %GenQueue.Job{module: Job, args: []} = job
    end

    test "enqueues and runs job from module and single map args" do
      {:ok, job} = Enqueuer.push({Job, [%{"foo" => "bar"}]})
      assert_receive({:performed, %{"foo" => "bar"}, "events"})
      assert %GenQueue.Job{module: Job, args: [%{"foo" => "bar"}]} = job
    end

    test "enqueues and runs job in a specific queue" do
      {:ok, job} = Enqueuer.push({Job, %{"foo" => "bar"}}, queue: "foo")
      assert_receive({:performed, %{"foo" => "bar"}, "foo"})
      assert %GenQueue.Job{module: Job, queue: "foo"} = job
    end

    test "schedules a job with millisecond based delay" do
      before = DateTime.utc_now()
      {:ok, job} = Enqueuer.push({Job, %{"foo" => "bar"}}, delay: 10_000)

      assert %GenQueue.Job{module: Job, delay: 10_000} = job

      assert %Oban.Job{state: "scheduled", args: %{"foo" => "bar"}, scheduled_at: scheduled_at} =
               Repo.one!(Oban.Job)

      assert DateTime.diff(scheduled_at, before, :millisecond) >= 10_000
      assert DateTime.diff(scheduled_at, DateTime.utc_now(), :millisecond) <= 10_000
    end

    test "schedules a job with datetime based delay" do
      at = DateTime.add(DateTime.utc_now(), 60, :second)
      {:ok, job} = Enqueuer.push({Job, %{"foo" => "bar"}}, delay: at)

      assert %GenQueue.Job{module: Job, delay: ^at} = job

      assert %Oban.Job{state: "scheduled", args: %{"foo" => "bar"}, scheduled_at: scheduled_at} =
               Repo.one!(Oban.Job)

      assert DateTime.compare(scheduled_at, at) == :eq
    end

    test "runs a delayed job once its delay has passed" do
      {:ok, _} = Enqueuer.push({Job, %{"foo" => "bar"}}, delay: 0)
      assert_receive({:performed, %{"foo" => "bar"}, "events"})
    end

    test "returns an error if Oban rejects the job" do
      queue = String.duplicate("a", 129)
      assert {:error, %Ecto.Changeset{valid?: false}} = Enqueuer.push(Job, queue: queue)
      assert Repo.aggregate(Oban.Job, :count, :id) == 0
    end

    test "raises if args are not empty or a single map" do
      assert_raise ArgumentError, fn -> Enqueuer.push({Job, ["foo", "bar"]}) end
      assert_raise ArgumentError, fn -> Enqueuer.push({Job, "foo"}) end
    end
  end
end
