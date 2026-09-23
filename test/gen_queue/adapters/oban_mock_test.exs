defmodule GenQueue.Adapters.ObanMockTest do
  use ExUnit.Case, async: true

  import GenQueue.Test

  defmodule Enqueuer do
    Application.put_env(:gen_queue_oban, __MODULE__, adapter: GenQueue.Adapters.MockJob)

    use GenQueue, otp_app: :gen_queue_oban
  end

  defmodule Job do
    use Oban.Worker, queue: "events"

    @impl Oban.Worker
    def perform(_args, _job), do: :ok
  end

  setup do
    setup_test_queue(Enqueuer)
  end

  describe "push/2" do
    test "sends the job back to the registered process from module" do
      {:ok, _} = Enqueuer.push(Job)
      assert_receive(%GenQueue.Job{module: Job, args: []})
    end

    test "sends the job back to the registered process from module and map arg" do
      {:ok, _} = Enqueuer.push({Job, %{"foo" => "bar"}})
      assert_receive(%GenQueue.Job{module: Job, args: [%{"foo" => "bar"}]})
    end

    test "sends the job back to the registered process with queue" do
      {:ok, _} = Enqueuer.push({Job, %{"foo" => "bar"}}, queue: "foo")
      assert_receive(%GenQueue.Job{module: Job, args: [%{"foo" => "bar"}], queue: "foo"})
    end

    test "sends the job back to the registered process with millisecond delay" do
      {:ok, _} = Enqueuer.push(Job, delay: 10_000)
      assert_receive(%GenQueue.Job{module: Job, args: [], delay: 10_000})
    end

    test "sends the job back to the registered process with datetime delay" do
      {:ok, _} = Enqueuer.push(Job, delay: DateTime.utc_now())
      assert_receive(%GenQueue.Job{module: Job, args: [], delay: %DateTime{}})
    end

    test "does nothing if process is not registered" do
      reset_test_queue(Enqueuer)
      {:ok, _} = Enqueuer.push(Job)
      refute_receive(%GenQueue.Job{})
    end
  end
end
