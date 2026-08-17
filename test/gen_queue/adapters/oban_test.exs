defmodule GenQueue.Adapters.ObanTest do
  use ExUnit.Case

  alias GenQueue.Adapters.Oban.Repo
  alias GenQueue.Adapters.Oban.TestJob
  alias GenQueue.Adapters.Oban.TestQueue

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  test "push/1 with simple job module" do
    assert {:ok, %GenQueue.Job{module: TestJob, args: [%{}]}} = TestQueue.push(TestJob)
  end

  test "push/1 with job tuple without args" do
    assert {:ok, %GenQueue.Job{module: TestJob, args: [%{}]}} = TestQueue.push({TestJob})
  end

  test "push/1 with job tuple and map args" do
    assert {:ok, %GenQueue.Job{module: TestJob, args: [%{"foo" => "bar"}]}} =
             TestQueue.push({TestJob, %{"foo" => "bar"}})
  end

  test "push/1 with job tuple and list args" do
    assert {:ok, %GenQueue.Job{module: TestJob, args: [%{}]}} = TestQueue.push({TestJob, []})

    assert {:ok, %GenQueue.Job{module: TestJob, args: [%{"foo" => "bar"}]}} =
             TestQueue.push({TestJob, [%{"foo" => "bar"}]})
  end

  test "push/2 with delay as integer milliseconds" do
    assert {:ok, %GenQueue.Job{module: TestJob, args: [%{"foo" => "bar"}], delay: 10_000}} =
             TestQueue.push({TestJob, %{"foo" => "bar"}}, delay: 10_000)
  end

  test "push/2 with delay as DateTime" do
    date = DateTime.utc_now()

    assert {:ok, %GenQueue.Job{module: TestJob, args: [%{"foo" => "bar"}], delay: ^date}} =
             TestQueue.push({TestJob, %{"foo" => "bar"}}, delay: date)
  end
end
