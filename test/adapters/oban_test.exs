defmodule GenQueue.Adapters.ObanTest do
  use ExUnit.Case

  import GenQueue.Test

  alias GenQueue.ObanTest.Repo

  defmodule Enqueuer do
    Application.put_env(:gen_queue_oban, __MODULE__, adapter: GenQueue.Adapters.Oban)

    use GenQueue, otp_app: :gen_queue_oban
  end

  defmodule Job do
    use Oban.Worker

    @impl Oban.Worker
    def perform(args, _job) do
      send_item(Enqueuer, {:performed, args})
      :ok
    end
  end

  defmodule EventsJob do
    use Oban.Worker, queue: "events"

    @impl Oban.Worker
    def perform(args, _job) do
      send_item(Enqueuer, {:performed_event, args})
      :ok
    end
  end

  @oban_opts [repo: Repo, queues: [default: 10, events: 1, q1: 1, q2: 1], poll_interval: 100]

  setup do
    Repo.delete_all(Oban.Job)
    start_supervised!({Enqueuer, @oban_opts})
    setup_global_test_queue(Enqueuer, :test)
  end

  describe "start_link/1" do
    test "starts Oban with the given options" do
      assert %Oban.Config{repo: Repo, poll_interval: 100} = Oban.config()
    end
  end

  describe "push/2" do
    test "enqueues and runs job from module" do
      {:ok, job} = Enqueuer.push(Job)
      assert_receive({:performed, %{}})
      assert %GenQueue.Job{module: Job, args: [%{}], queue: "default"} = job
    end

    test "enqueues and runs job from module tuple" do
      {:ok, job} = Enqueuer.push({Job})
      assert_receive({:performed, %{}})
      assert %GenQueue.Job{module: Job, args: [%{}], queue: "default"} = job
    end

    test "enqueues and runs job from module and map arg" do
      {:ok, job} = Enqueuer.push({Job, %{"foo" => "bar"}})
      assert_receive({:performed, %{"foo" => "bar"}})
      assert %GenQueue.Job{module: Job, args: [%{"foo" => "bar"}], queue: "default"} = job
    end

    test "enqueues and runs job from module and empty args" do
      {:ok, job} = Enqueuer.push({Job, []})
      assert_receive({:performed, %{}})
      assert %GenQueue.Job{module: Job, args: [%{}], queue: "default"} = job
    end

    test "enqueues and runs job from module and map in args" do
      {:ok, job} = Enqueuer.push({Job, [%{"foo" => "bar"}]})
      assert_receive({:performed, %{"foo" => "bar"}})
      assert %GenQueue.Job{module: Job, args: [%{"foo" => "bar"}], queue: "default"} = job
    end

    test "enqueues a job to the queue configured by the worker" do
      {:ok, job} = Enqueuer.push({EventsJob, %{"foo" => "bar"}})
      assert_receive({:performed_event, %{"foo" => "bar"}})
      assert %GenQueue.Job{module: EventsJob, queue: "events"} = job
    end

    test "enqueues a job to a specific queue" do
      {:ok, job1} = Enqueuer.push({Job, %{"id" => 1}}, queue: "q1")
      {:ok, job2} = Enqueuer.push({Job, %{"id" => 2}}, queue: :q2)
      assert_receive({:performed, %{"id" => 1}})
      assert_receive({:performed, %{"id" => 2}})
      assert %GenQueue.Job{module: Job, args: [%{"id" => 1}], queue: "q1"} = job1
      assert %GenQueue.Job{module: Job, args: [%{"id" => 2}], queue: "q2"} = job2
    end

    test "enqueues a job with millisecond based delay" do
      {:ok, job} = Enqueuer.push({Job, %{}}, delay: 0)
      assert_receive({:performed, %{}})
      assert %GenQueue.Job{module: Job, args: [%{}], delay: 0} = job
    end

    test "schedules a job in the future with millisecond based delay" do
      {:ok, _} = Enqueuer.push({Job, %{}}, delay: 60_000)
      assert [%Oban.Job{state: "scheduled", scheduled_at: scheduled_at}] = Repo.all(Oban.Job)
      scheduled_in = DateTime.diff(scheduled_at, DateTime.utc_now(), :millisecond)
      assert_in_delta(scheduled_in, 60_000, 1_000)
      refute_receive({:performed, _}, 500)
    end

    test "enqueues a job with datetime based delay" do
      {:ok, job} = Enqueuer.push({Job, %{}}, delay: DateTime.utc_now())
      assert_receive({:performed, %{}})
      assert %GenQueue.Job{module: Job, args: [%{}], delay: %DateTime{}} = job
    end

    test "schedules a job in the future with datetime based delay" do
      at = DateTime.add(DateTime.utc_now(), 3_600, :second)
      {:ok, _} = Enqueuer.push({Job, %{}}, delay: at)
      assert [%Oban.Job{state: "scheduled", scheduled_at: scheduled_at}] = Repo.all(Oban.Job)
      assert DateTime.compare(scheduled_at, at) == :eq
      refute_receive({:performed, _}, 500)
    end

    test "returns an error when the job arg is not a map" do
      assert {:error, :invalid_args} = Enqueuer.push({Job, "foo"})
      assert [] = Repo.all(Oban.Job)
    end

    test "returns an error when the job has multiple args" do
      assert {:error, :invalid_args} = Enqueuer.push({Job, [%{"foo" => "bar"}, %{"baz" => 1}]})
      assert [] = Repo.all(Oban.Job)
    end
  end
end
