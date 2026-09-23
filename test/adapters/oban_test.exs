defmodule GenQueue.Adapters.ObanTest do
  use ExUnit.Case

  import GenQueue.Test

  alias GenQueueOban.Test.Repo

  defmodule Enqueuer do
    Application.put_env(:gen_queue_oban, __MODULE__, adapter: GenQueue.Adapters.Oban)

    use GenQueue, otp_app: :gen_queue_oban
  end

  defmodule Job do
    use Oban.Worker

    @impl Oban.Worker
    def perform(args, job) do
      send_item(Enqueuer, {:performed, job.queue, args})
    end
  end

  defmodule EventJob do
    use Oban.Worker, queue: "events"

    @impl Oban.Worker
    def perform(args, job) do
      send_item(Enqueuer, {:performed, job.queue, args})
    end
  end

  setup do
    Repo.delete_all(Oban.Job)
    on_exit(fn -> Repo.delete_all(Oban.Job) end)

    setup_global_test_queue(Enqueuer, :test)
  end

  describe "push/2" do
    test "enqueues and runs job from module" do
      assert {:ok, job} = Enqueuer.push(Job)
      assert %GenQueue.Job{module: Job, args: [], queue: "default"} = job
      assert_receive({:performed, "default", %{}})
    end

    test "enqueues and runs job from module tuple" do
      assert {:ok, job} = Enqueuer.push({Job})
      assert %GenQueue.Job{module: Job, args: [], queue: "default"} = job
      assert_receive({:performed, "default", %{}})
    end

    test "enqueues and runs job from module and map arg" do
      assert {:ok, job} = Enqueuer.push({Job, %{"foo" => "bar"}})
      assert %GenQueue.Job{module: Job, args: [%{"foo" => "bar"}], queue: "default"} = job
      assert_receive({:performed, "default", %{"foo" => "bar"}})
    end

    test "enqueues and runs job from module and empty args" do
      assert {:ok, job} = Enqueuer.push({Job, []})
      assert %GenQueue.Job{module: Job, args: [], queue: "default"} = job
      assert_receive({:performed, "default", %{}})
    end

    test "enqueues and runs job from module and map in args" do
      assert {:ok, job} = Enqueuer.push({Job, [%{"foo" => "bar"}]})
      assert %GenQueue.Job{module: Job, args: [%{"foo" => "bar"}], queue: "default"} = job
      assert_receive({:performed, "default", %{"foo" => "bar"}})
    end

    test "enqueues a job to a specific queue" do
      assert {:ok, job} = Enqueuer.push({Job, %{"foo" => "bar"}}, queue: "q1")
      assert %GenQueue.Job{module: Job, queue: "q1"} = job
      assert_receive({:performed, "q1", %{"foo" => "bar"}})
    end

    test "enqueues a job to the queue configured by its worker" do
      assert {:ok, %GenQueue.Job{queue: "events"}} = Enqueuer.push(EventJob)
      assert_receive({:performed, "events", %{}})

      assert {:ok, %GenQueue.Job{queue: "q1"}} = Enqueuer.push(EventJob, queue: "q1")
      assert_receive({:performed, "q1", %{}})
    end

    test "enqueues a job with millisecond based delay" do
      assert {:ok, job} = Enqueuer.push({Job, %{"foo" => "bar"}}, delay: 10_000)
      assert %GenQueue.Job{module: Job, queue: "default", delay: 10_000} = job

      assert [%Oban.Job{state: "scheduled", scheduled_at: scheduled_at}] = Repo.all(Oban.Job)
      assert_in_delta DateTime.diff(scheduled_at, DateTime.utc_now()), 10, 1
      refute_receive({:performed, _, _}, 500)
    end

    test "enqueues and runs a job with elapsed millisecond based delay" do
      assert {:ok, %GenQueue.Job{delay: 0}} = Enqueuer.push({Job, %{"foo" => "bar"}}, delay: 0)
      assert_receive({:performed, "default", %{"foo" => "bar"}})
    end

    test "enqueues a job with datetime based delay" do
      scheduled_at = DateTime.add(DateTime.utc_now(), 60)

      assert {:ok, job} = Enqueuer.push({Job, %{"foo" => "bar"}}, delay: scheduled_at)
      assert %GenQueue.Job{module: Job, queue: "default", delay: ^scheduled_at} = job

      assert [%Oban.Job{state: "scheduled"} = oban_job] = Repo.all(Oban.Job)
      assert DateTime.compare(oban_job.scheduled_at, scheduled_at) == :eq
      refute_receive({:performed, _, _}, 500)
    end

    test "enqueues and runs a job with elapsed datetime based delay" do
      assert {:ok, _job} = Enqueuer.push({Job, %{"foo" => "bar"}}, delay: DateTime.utc_now())
      assert_receive({:performed, "default", %{"foo" => "bar"}})
    end

    test "returns an error for args that are not a single map" do
      assert {:error, {:invalid_args, ["foo"]}} = Enqueuer.push({Job, "foo"})
      assert {:error, {:invalid_args, [%{}, %{}]}} = Enqueuer.push({Job, [%{}, %{}]})
      assert [] = Repo.all(Oban.Job)
    end

    test "returns an error for jobs that Oban rejects" do
      queue = String.duplicate("q", 129)

      assert {:error, %Ecto.Changeset{valid?: false}} = Enqueuer.push(Job, queue: queue)
      assert [] = Repo.all(Oban.Job)
    end
  end

  test "enqueuer can be started as part of a supervision tree without starting Oban" do
    assert :ignore = Enqueuer.start_link()
    assert {:ok, pid} = Supervisor.start_link([{Enqueuer, []}], strategy: :one_for_one)
    assert {:ok, _job} = Enqueuer.push(Job)
    assert_receive({:performed, "default", %{}})
    Supervisor.stop(pid)
  end
end
