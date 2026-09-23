defmodule GenQueue.Adapters.ObanMockTest do
  use ExUnit.Case, async: true

  import GenQueue.Test

  alias GenQueueOban.TestJob

  defmodule MockEnqueuer do
    use GenQueue, adapter: GenQueue.Adapters.MockJob
  end

  setup do
    setup_test_queue(MockEnqueuer)
  end

  test "sends a zero-arg job back to the current process" do
    {:ok, _} = MockEnqueuer.push(TestJob)
    assert_receive(%GenQueue.Job{module: TestJob, args: []})
  end

  test "sends a job with a map arg back to the current process" do
    {:ok, _} = MockEnqueuer.push({TestJob, %{"foo" => "bar"}})
    assert_receive(%GenQueue.Job{module: TestJob, args: [%{"foo" => "bar"}]})
  end

  test "sends a job with options back to the current process" do
    {:ok, _} = MockEnqueuer.push({TestJob, %{"foo" => "bar"}}, queue: "foo", delay: 1_000)

    assert_receive(%GenQueue.Job{
      module: TestJob,
      args: [%{"foo" => "bar"}],
      queue: "foo",
      delay: 1_000
    })
  end
end
