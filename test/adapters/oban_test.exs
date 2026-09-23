defmodule GenQueue.Adapters.ObanTest do
  use ExUnit.Case

  import GenQueue.Test

  alias GenQueue.ObanTest.Repo

  defmodule Enqueuer do
    Application.put_env(:gen_queue_oban, __MODULE__, adapter: GenQueue.Adapters.Oban)

    use GenQueue, otp_app: :gen_queue_oban
  end

  defmodule Job do
    use Oban.Worker, queue: "default"

    @impl Oban.Worker
    def perform(args, _job) do
      send_item(Enqueuer, {:performed, args})
    end
  end

  setup do
    Repo.delete_all(Oban.Job)
    start_supervised!({Oban, repo: Repo, queues: [default: 5, q1: 5], poll_interval: 50})
    setup_global_test_queue(Enqueuer, :test)
  end

  describe "push/2" do
    test "enqueues and runs job from module" do
      {:ok, job} = Enqueuer.push(Job)
      assert_receive({:performed, %{}})
      assert %GenQueue.Job{module: Job, args: [], queue: "default"} = job
    end

    test "enqueues and runs job from module tuple" do
      {:ok, job} = Enqueuer.push({Job})
      assert_receive({:performed, %{}})
      assert %GenQueue.Job{module: Job, args: [], queue: "default"} = job
    end

    test "enqueues and runs job from module and arg" do
      {:ok, job} = Enqueuer.push({Job, %{"foo" => "bar"}})
      assert_receive({:performed, %{"foo" => "bar"}})
      assert %GenQueue.Job{module: Job, args: [%{"foo" => "bar"}], queue: "default"} = job
    end

    test "enqueues and runs job from module and args" do
      {:ok, job} = Enqueuer.push({Job, [%{"foo" => "bar"}]})
      assert_receive({:performed, %{"foo" => "bar"}})
      assert %GenQueue.Job{module: Job, args: [%{"foo" => "bar"}], queue: "default"} = job
    end

    test "returns an error for args that are not a single map" do
      assert {:error, :invalid_args} = Enqueuer.push({Job, "foo"})
      assert {:error, :invalid_args} = Enqueuer.push({Job, [%{}, %{}]})
    end

    test "enqueues a job with millisecond based delay" do
      {:ok, job} = Enqueuer.push({Job, []}, delay: 0)
      assert_receive({:performed, %{}})
      assert %GenQueue.Job{module: Job, args: [], queue: "default", delay: 0} = job
    end

    test "enqueues a job with datetime based delay" do
      {:ok, job} = Enqueuer.push({Job, []}, delay: DateTime.utc_now())
      assert_receive({:performed, %{}})
      assert %GenQueue.Job{module: Job, args: [], queue: "default", delay: %DateTime{}} = job
    end

    test "enqueues a job to a specific queue" do
      {:ok, job} = Enqueuer.push({Job, %{"id" => 1}}, queue: "q1")
      assert_receive({:performed, %{"id" => 1}})
      assert %GenQueue.Job{module: Job, queue: "q1"} = job
      assert [%Oban.Job{queue: "q1"}] = Repo.all(Oban.Job)
    end

    test "passes config through as oban job options" do
      {:ok, _} = Enqueuer.push({Job, %{"id" => 1}}, config: [max_attempts: 3])
      assert_receive({:performed, %{"id" => 1}})
      assert [%Oban.Job{max_attempts: 3}] = Repo.all(Oban.Job)
    end
  end

  test "enqueuer can be started as part of a supervision tree" do
    {:ok, pid} = Supervisor.start_link([{Enqueuer, []}], strategy: :one_for_one)
    {:ok, _} = Enqueuer.push(Job)
    assert_receive({:performed, %{}})
    Supervisor.stop(pid)
  end
end
