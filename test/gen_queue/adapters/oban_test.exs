defmodule GenQueue.Adapters.ObanTest do
  use ExUnit.Case

  import GenQueue.Test

  alias GenQueueOban.Repo

  defmodule Enqueuer do
    Application.put_env(:gen_queue_oban, __MODULE__,
      adapter: GenQueue.Adapters.Oban,
      repo: GenQueueOban.Repo,
      queues: false
    )

    use GenQueue, otp_app: :gen_queue_oban
  end

  defmodule Job do
    use Oban.Worker, queue: "default", max_attempts: 1

    @impl Oban.Worker
    def perform(args, _job) do
      send_item(Enqueuer, {:performed, args})
      :ok
    end
  end

  setup do
    start_supervised!(Enqueuer)

    Repo.delete_all(Oban.Job)

    setup_test_queue(Enqueuer)
  end

  describe "push/2" do
    test "enqueues and runs job from module" do
      {:ok, job} = Enqueuer.push(Job)

      assert %GenQueue.Job{module: Job, args: [%{}]} = job
      assert %{success: 1} = Oban.drain_queue(:default)
      assert_receive({:performed, %{}})
    end

    test "enqueues and runs job from module tuple" do
      {:ok, job} = Enqueuer.push({Job})

      assert %GenQueue.Job{module: Job, args: [%{}]} = job
      assert %{success: 1} = Oban.drain_queue(:default)
      assert_receive({:performed, %{}})
    end

    test "enqueues and runs job from module and empty args" do
      {:ok, job} = Enqueuer.push({Job, []})

      assert %GenQueue.Job{module: Job, args: [%{}]} = job
      assert %{success: 1} = Oban.drain_queue(:default)
      assert_receive({:performed, %{}})
    end

    test "enqueues and runs job from module and args" do
      {:ok, job} = Enqueuer.push({Job, [%{"foo" => "bar"}]})

      assert %GenQueue.Job{module: Job, args: [%{"foo" => "bar"}]} = job
      assert %{success: 1} = Oban.drain_queue(:default)
      assert_receive({:performed, %{"foo" => "bar"}})
    end

    test "enqueues and runs job from module and single arg" do
      {:ok, job} = Enqueuer.push({Job, %{"foo" => "bar"}})

      assert %GenQueue.Job{module: Job, args: [%{"foo" => "bar"}]} = job
      assert %{success: 1} = Oban.drain_queue(:default)
      assert_receive({:performed, %{"foo" => "bar"}})
    end

    test "enqueues a job with the queue from the job module" do
      {:ok, _} = Enqueuer.push({Job, %{}})

      assert %Oban.Job{queue: "default"} = only_oban_job()
    end

    test "enqueues a job with a queue" do
      {:ok, job} = Enqueuer.push({Job, %{}}, queue: "foo")

      assert %GenQueue.Job{queue: "foo"} = job
      assert %Oban.Job{queue: "foo"} = only_oban_job()
    end

    test "enqueues a job with millisecond based delay" do
      {:ok, job} = Enqueuer.push({Job, %{}}, delay: 60_000)

      assert %GenQueue.Job{delay: 60_000} = job
      assert %Oban.Job{state: "scheduled", scheduled_at: scheduled_at} = only_oban_job()
      assert_in_delta DateTime.diff(scheduled_at, DateTime.utc_now()), 60, 5
    end

    test "enqueues a job with datetime based delay" do
      delay = DateTime.add(DateTime.utc_now(), 60)

      {:ok, job} = Enqueuer.push({Job, %{}}, delay: delay)

      assert %GenQueue.Job{delay: ^delay} = job
      assert %Oban.Job{state: "scheduled", scheduled_at: scheduled_at} = only_oban_job()
      assert DateTime.compare(scheduled_at, delay) == :eq
    end
  end

  defp only_oban_job do
    [oban_job] = Repo.all(Oban.Job)

    oban_job
  end
end
