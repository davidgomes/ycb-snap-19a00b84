defmodule GenQueue.Adapters.ObanMockTest do
  use ExUnit.Case, async: true

  import GenQueue.Test

  alias GenQueue.Oban.Test.{Job, MockEnqueuer}

  setup do
    setup_test_queue(MockEnqueuer)
  end

  test "sends the job back to the test process" do
    {:ok, _} = MockEnqueuer.push(Job)
    assert_receive(%GenQueue.Job{module: Job, args: []})
  end

  test "sends the job with args back to the test process" do
    {:ok, _} = MockEnqueuer.push({Job, %{"foo" => "bar"}})
    assert_receive(%GenQueue.Job{module: Job, args: [%{"foo" => "bar"}]})
  end

  test "sends the job with options back to the test process" do
    {:ok, _} = MockEnqueuer.push({Job, %{"foo" => "bar"}}, queue: "foo", delay: 10_000)

    assert_receive(%GenQueue.Job{
      module: Job,
      args: [%{"foo" => "bar"}],
      queue: "foo",
      delay: 10_000
    })
  end
end
