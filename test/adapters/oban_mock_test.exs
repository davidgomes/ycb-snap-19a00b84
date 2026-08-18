defmodule GenQueue.Adapters.ObanMockTest do
  use ExUnit.Case, async: true

  import GenQueue.Test

  defmodule Enqueuer do
    Application.put_env(:gen_queue_oban, __MODULE__, adapter: GenQueue.Adapters.MockJob)

    use GenQueue, otp_app: :gen_queue_oban
  end

  defmodule Job do
    use Oban.Worker

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

    test "sends the job back to the registered process from module and arg" do
      {:ok, _} = Enqueuer.push({Job, %{"foo" => "bar"}})
      assert_receive(%GenQueue.Job{module: Job, args: [%{"foo" => "bar"}]})
    end

    test "sends the job back to the registered process with queue and delay" do
      {:ok, _} = Enqueuer.push({Job, %{}}, queue: "foo", delay: 10_000)
      assert_receive(%GenQueue.Job{module: Job, args: [%{}], queue: "foo", delay: 10_000})
    end

    test "does nothing if process is not registered" do
      reset_test_queue(Enqueuer)
      {:ok, _} = Enqueuer.push(Job)
    end
  end
end
