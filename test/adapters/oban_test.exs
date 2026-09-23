defmodule GenQueue.Adapters.ObanTest do
  use ExUnit.Case

  import Ecto.Query

  alias GenQueue.Oban.Test.Repo

  defmodule Enqueuer do
    use GenQueue, adapter: GenQueue.Adapters.Oban
  end

  defmodule Job do
    use Oban.Worker, queue: "events", max_attempts: 10

    @impl Oban.Worker
    def perform(_args, _job), do: :ok
  end

  setup do
    Repo.delete_all(Oban.Job)
    :ok
  end

  describe "start_link/2" do
    test "does not start a process" do
      assert :ignore = Enqueuer.start_link()
    end
  end

  describe "push/2" do
    test "enqueues a module job with empty args" do
      {:ok, job} = Enqueuer.push(Job)

      assert %GenQueue.Job{module: Job, args: []} = job
      assert %Oban.Job{args: %{}, queue: "events", worker: worker} = fetch_oban_job()
      assert worker == inspect(Job)
    end

    test "enqueues a single element tuple job with empty args" do
      {:ok, _} = Enqueuer.push({Job})

      assert %Oban.Job{args: %{}} = fetch_oban_job()
    end

    test "enqueues a job with map args" do
      {:ok, _} = Enqueuer.push({Job, %{"foo" => "bar"}})

      assert %Oban.Job{args: %{"foo" => "bar"}} = fetch_oban_job()
    end

    test "enqueues a job with empty list args" do
      {:ok, _} = Enqueuer.push({Job, []})

      assert %Oban.Job{args: %{}} = fetch_oban_job()
    end

    test "enqueues a job with a map in list args" do
      {:ok, _} = Enqueuer.push({Job, [%{"foo" => "bar"}]})

      assert %Oban.Job{args: %{"foo" => "bar"}} = fetch_oban_job()
    end

    test "returns an error for non-map args" do
      assert {:error, %GenQueue.Error{}} = Enqueuer.push({Job, ["foo", "bar"]})
      assert {:error, %GenQueue.Error{}} = Enqueuer.push({Job, "foo"})
      assert Repo.aggregate(Oban.Job, :count, :id) == 0
    end

    test "uses the worker queue by default" do
      {:ok, _} = Enqueuer.push(Job)

      assert %Oban.Job{queue: "events"} = fetch_oban_job()
    end

    test "enqueues a job to a specific queue" do
      {:ok, job} = Enqueuer.push({Job, %{"foo" => "bar"}}, queue: "foo")

      assert %GenQueue.Job{queue: "foo"} = job
      assert %Oban.Job{queue: "foo"} = fetch_oban_job()
    end

    test "enqueues a job to an atom queue" do
      {:ok, _} = Enqueuer.push(Job, queue: :foo)

      assert %Oban.Job{queue: "foo"} = fetch_oban_job()
    end

    test "schedules a job with a millisecond delay" do
      now = DateTime.utc_now()
      {:ok, job} = Enqueuer.push({Job, %{"foo" => "bar"}}, delay: 10_000)

      assert %GenQueue.Job{delay: 10_000} = job
      assert %Oban.Job{state: "scheduled", scheduled_at: scheduled_at} = fetch_oban_job()
      assert_in_delta DateTime.diff(scheduled_at, now), 10, 1
    end

    test "schedules a job at a specific time" do
      date = DateTime.add(DateTime.utc_now(), 3600)
      {:ok, _} = Enqueuer.push({Job, %{"foo" => "bar"}}, delay: date)

      assert %Oban.Job{state: "scheduled", scheduled_at: scheduled_at} = fetch_oban_job()
      assert DateTime.diff(scheduled_at, date) == 0
    end

    test "passes config through as job options" do
      {:ok, _} = Enqueuer.push(Job, config: [max_attempts: 3, priority: 2])

      assert %Oban.Job{max_attempts: 3, priority: 2} = fetch_oban_job()
    end

    test "uses the worker options by default" do
      {:ok, _} = Enqueuer.push(Job)

      assert %Oban.Job{max_attempts: 10} = fetch_oban_job()
    end

    test "returns an error for an invalid job" do
      assert {:error, %Ecto.Changeset{}} = Enqueuer.push(Job, config: [max_attempts: 0])
    end
  end

  defp fetch_oban_job do
    Repo.one!(from(j in Oban.Job))
  end
end
