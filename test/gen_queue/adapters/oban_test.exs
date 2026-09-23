defmodule GenQueue.Adapters.ObanTest do
  use ExUnit.Case, async: true

  alias GenQueue.Oban.Test.{Enqueuer, Job, Repo}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  defp jobs do
    Repo.all(Oban.Job)
  end

  describe "push/2" do
    test "enqueues a job with only a module" do
      assert {:ok, %GenQueue.Job{module: Job, args: [%{}]}} = Enqueuer.push(Job)
      assert [%Oban.Job{worker: "GenQueue.Oban.Test.Job", args: %{}, queue: "test"}] = jobs()
    end

    test "enqueues a job with a single element tuple" do
      assert {:ok, %GenQueue.Job{args: [%{}]}} = Enqueuer.push({Job})
      assert [%Oban.Job{args: %{}}] = jobs()
    end

    test "enqueues a job with a map arg" do
      assert {:ok, %GenQueue.Job{args: [%{"foo" => "bar"}]}} =
               Enqueuer.push({Job, %{"foo" => "bar"}})

      assert [%Oban.Job{args: %{"foo" => "bar"}}] = jobs()
    end

    test "enqueues a job with an empty arg list" do
      assert {:ok, %GenQueue.Job{args: [%{}]}} = Enqueuer.push({Job, []})
      assert [%Oban.Job{args: %{}}] = jobs()
    end

    test "enqueues a job with a map in an arg list" do
      assert {:ok, _} = Enqueuer.push({Job, [%{"foo" => "bar"}]})
      assert [%Oban.Job{args: %{"foo" => "bar"}}] = jobs()
    end

    test "enqueues a job to a specific queue" do
      assert {:ok, %GenQueue.Job{queue: "foo"}} = Enqueuer.push(Job, queue: "foo")
      assert [%Oban.Job{queue: "foo"}] = jobs()
    end

    test "schedules a job with a millisecond delay" do
      assert {:ok, %GenQueue.Job{delay: 10_000}} = Enqueuer.push(Job, delay: 10_000)
      assert [%Oban.Job{state: "scheduled", scheduled_at: scheduled_at}] = jobs()

      diff = DateTime.diff(scheduled_at, DateTime.utc_now())
      assert diff > 8 and diff <= 10
    end

    test "schedules a job at a specific time" do
      at = DateTime.add(DateTime.utc_now(), 3600, :second)

      assert {:ok, %GenQueue.Job{delay: ^at}} = Enqueuer.push(Job, delay: at)
      assert [%Oban.Job{state: "scheduled", scheduled_at: ^at}] = jobs()
    end

    test "returns an error for non-map args" do
      assert {:error, :invalid_args} = Enqueuer.push({Job, "foo"})
      assert {:error, :invalid_args} = Enqueuer.push({Job, [%{}, %{}]})
      assert [] = jobs()
    end
  end
end
