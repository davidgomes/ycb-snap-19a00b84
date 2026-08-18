defmodule GenQueue.Adapters.ObanTest do
  use ExUnit.Case

  import GenQueue.Test
  import GenQueue.ObanTestHelpers

  alias GenQueue.Oban.Repo

  defmodule Enqueuer do
    Application.put_env(:gen_queue_oban, __MODULE__, adapter: GenQueue.Adapters.Oban)

    use GenQueue, otp_app: :gen_queue_oban
  end

  defmodule ConfiguredEnqueuer do
    Application.put_env(:gen_queue_oban, __MODULE__,
      adapter: GenQueue.Adapters.Oban,
      repo: GenQueue.Oban.Repo,
      queues: false
    )

    use GenQueue, otp_app: :gen_queue_oban
  end

  defmodule Job do
    use Oban.Worker, queue: "default", max_attempts: 1

    @impl Oban.Worker
    def perform(args, _job) do
      send_item(Enqueuer, {:performed, args})
    end
  end

  setup do
    Repo.delete_all(Oban.Job)

    setup_global_test_queue(Enqueuer, :test)
  end

  describe "push/2" do
    setup do
      start_supervised!({Enqueuer, [repo: Repo, queues: false]})

      :ok
    end

    test "enqueues a job from module" do
      assert {:ok, %GenQueue.Job{module: Job, args: [%{}]}} = Enqueuer.push(Job)
      assert [%Oban.Job{args: %{}, queue: "default", state: "available"}] = all_jobs()
    end

    test "enqueues a job from module tuple" do
      assert {:ok, %GenQueue.Job{module: Job, args: [%{}]}} = Enqueuer.push({Job})
      assert [%Oban.Job{args: %{}, queue: "default", state: "available"}] = all_jobs()
    end

    test "enqueues a job from module and empty args" do
      assert {:ok, %GenQueue.Job{module: Job, args: [%{}]}} = Enqueuer.push({Job, []})
      assert [%Oban.Job{args: %{}, queue: "default"}] = all_jobs()
    end

    test "enqueues a job from module and arg" do
      assert {:ok, %GenQueue.Job{module: Job, args: [%{"foo" => "bar"}]}} =
               Enqueuer.push({Job, %{"foo" => "bar"}})

      assert [%Oban.Job{args: %{"foo" => "bar"}}] = all_jobs()
    end

    test "enqueues a job from module and args" do
      assert {:ok, %GenQueue.Job{module: Job, args: [%{"foo" => "bar"}]}} =
               Enqueuer.push({Job, [%{"foo" => "bar"}]})

      assert [%Oban.Job{args: %{"foo" => "bar"}}] = all_jobs()
    end

    test "enqueues a job to a specific queue" do
      assert {:ok, %GenQueue.Job{queue: "foo"}} = Enqueuer.push({Job, %{}}, queue: "foo")
      assert [%Oban.Job{queue: "foo"}] = all_jobs()
    end

    test "enqueues a job with millisecond based delay" do
      assert {:ok, %GenQueue.Job{delay: 10_000}} = Enqueuer.push({Job, %{}}, delay: 10_000)
      assert [%Oban.Job{state: "scheduled", scheduled_at: scheduled_at}] = all_jobs()
      assert_in_delta DateTime.diff(scheduled_at, DateTime.utc_now(), :millisecond), 10_000, 1_000
    end

    test "enqueues a job with datetime based delay" do
      delay = DateTime.add(DateTime.utc_now(), 60, :second)

      assert {:ok, %GenQueue.Job{delay: ^delay}} = Enqueuer.push({Job, %{}}, delay: delay)
      assert [%Oban.Job{state: "scheduled", scheduled_at: scheduled_at}] = all_jobs()
      assert DateTime.compare(scheduled_at, delay) == :eq
    end

    test "does not enqueue a job with args that arent a map" do
      assert {:error, :invalid_args} = Enqueuer.push({Job, "foo"})
      assert [] = all_jobs()
    end
  end

  describe "push/2 with running queues" do
    setup do
      start_supervised!({Enqueuer, [repo: Repo, queues: [default: 5], poll_interval: 100]})

      :ok
    end

    test "runs a job with the pushed args" do
      {:ok, _} = Enqueuer.push({Job, %{"foo" => "bar"}})

      assert_receive({:performed, %{"foo" => "bar"}})
    end

    test "runs a scheduled job" do
      {:ok, _} = Enqueuer.push({Job, %{"foo" => "bar"}}, delay: 0)

      assert_receive({:performed, %{"foo" => "bar"}})
    end
  end

  test "enqueuer can be started with its oban config" do
    start_supervised!(ConfiguredEnqueuer)

    assert {:ok, %GenQueue.Job{module: Job, args: [%{}]}} = ConfiguredEnqueuer.push(Job)
    assert [%Oban.Job{args: %{}, queue: "default"}] = all_jobs()
  end

  test "enqueuer can be started as part of a supervision tree" do
    children = [{Enqueuer, [repo: Repo, queues: [default: 5], poll_interval: 100]}]

    {:ok, pid} = Supervisor.start_link(children, strategy: :one_for_one)
    {:ok, _} = Enqueuer.push(Job)

    assert_receive({:performed, %{}})

    stop_process(pid)
  end

  defp all_jobs do
    Repo.all(Oban.Job)
  end
end
