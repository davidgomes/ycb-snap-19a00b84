defmodule GenQueue.Adapters.ObanMockTest do
  use ExUnit.Case

  import GenQueue.Test

  defmodule Enqueuer do
    use GenQueue, adapter: GenQueue.Adapters.MockJob
  end

  defmodule Job do
    use Oban.Worker, queue: "events"

    @impl Oban.Worker
    def perform(_args, _job), do: :ok
  end

  setup do
    setup_test_queue(Enqueuer)
  end

  test "enqueuer can be started as part of a supervision tree" do
    {:ok, pid} = Supervisor.start_link([{Enqueuer, []}], strategy: :one_for_one)
    assert Process.alive?(pid)
  end

  test "sends the job back to the test process" do
    {:ok, _} = Enqueuer.push(Job)
    assert_receive(%GenQueue.Job{module: Job, args: []})
  end

  test "sends the job with args back to the test process" do
    {:ok, _} = Enqueuer.push({Job, %{"foo" => "bar"}}, queue: "foo")
    assert_receive(%GenQueue.Job{module: Job, args: [%{"foo" => "bar"}], queue: "foo"})
  end
end
