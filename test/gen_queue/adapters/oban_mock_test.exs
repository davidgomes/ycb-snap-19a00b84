defmodule GenQueue.Adapters.ObanMockTest do
  use ExUnit.Case, async: true

  import GenQueue.Test

  alias GenQueue.Oban.Test.{Job, MockEnqueuer}

  setup do
    setup_test_queue(MockEnqueuer)
  end

  test "sends a job with only a module to the test process" do
    assert {:ok, _} = MockEnqueuer.push(Job)
    assert_receive(%GenQueue.Job{module: Job, args: []})
  end

  test "sends a job with a map arg to the test process" do
    assert {:ok, _} = MockEnqueuer.push({Job, %{"foo" => "bar"}})
    assert_receive(%GenQueue.Job{module: Job, args: [%{"foo" => "bar"}]})
  end

  test "sends a job with options to the test process" do
    assert {:ok, _} = MockEnqueuer.push({Job, [%{"foo" => "bar"}]}, queue: "foo", delay: 1_000)

    assert_receive(%GenQueue.Job{
      module: Job,
      args: [%{"foo" => "bar"}],
      queue: "foo",
      delay: 1_000
    })
  end
end
