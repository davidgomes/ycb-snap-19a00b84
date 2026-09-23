defmodule ObanChore.IntegrationTest do
  use ObanChore.ObanCase, async: false

  defmodule PlainWorker do
    use Oban.Worker

    @impl Oban.Worker
    def perform(job), do: ObanChore.Test.Chores.checkpoint(job)
  end

  describe "job queries" do
    setup do
      start_oban!([Chores.Parked, Chores.UniqueParked])
      :ok
    end

    test "count_running/1 only counts active jobs for the given worker" do
      insert_job!(Chores.Parked, %{user_id: 1})
      Chores.Parked.new(%{user_id: 2}, schedule_in: 60) |> Oban.insert!()
      insert_completed!(Chores.Parked, %{user_id: 3})
      insert_job!(Chores.UniqueParked, %{account_id: 1})

      assert ObanChore.count_running(Chores.Parked) == 2
      assert ObanChore.count_running(Chores.UniqueParked) == 1
      assert ObanChore.count_running(Chores.Greeter) == 0
    end

    test "running_with_args?/2 matches active jobs containing the given args" do
      insert_job!(Chores.Parked, %{user_id: 1})
      insert_completed!(Chores.Parked, %{user_id: 2})

      assert ObanChore.running_with_args?(Chores.Parked, %{user_id: 1})
      assert ObanChore.running_with_args?(Chores.Parked, %{"user_id" => 1})
      refute ObanChore.running_with_args?(Chores.Parked, %{user_id: 2})
      refute ObanChore.running_with_args?(Chores.Parked, %{user_id: 3})
      refute ObanChore.running_with_args?(Chores.UniqueParked, %{user_id: 1})
    end

    test "list_active_jobs/1 returns active jobs with atom states" do
      available = insert_job!(Chores.Parked, %{user_id: 1})
      scheduled = Chores.Parked.new(%{user_id: 2}, schedule_in: 60) |> Oban.insert!()
      insert_completed!(Chores.Parked, %{user_id: 3})

      jobs = ObanChore.list_active_jobs(Chores.Parked)

      assert jobs |> Enum.map(&{&1.id, &1.state}) |> Enum.sort() ==
               [{available.id, :available}, {scheduled.id, :scheduled}]
    end
  end

  describe "telemetry broadcasts" do
    setup do
      start_oban!([Chores.Greeter, Chores.Failing],
        queues: [default: [limit: 5, paused: true]]
      )

      Phoenix.PubSub.subscribe(pubsub(), "oban_chore:counts")
      :ok
    end

    test "streams state changes, logs and counts for a successful job" do
      %{id: job_id} = job = insert_job!(Chores.Greeter, %{name: "Ada", times: 2})
      subscribe_job(job)
      Oban.resume_queue(queue: :default)

      assert {^job_id, pid} = await_job_started()
      assert_receive {:oban_chore_state, ^job_id, :executing}
      assert_receive {:oban_chore_count, Chores.Greeter, 1}

      release_job(pid)

      assert_receive {:oban_chore_log, ^job_id, "Hello, Ada!"}
      assert_receive {:oban_chore_log, ^job_id, "Hello, Ada!"}
      assert_receive {:oban_chore_state, ^job_id, :completed}
      assert_receive {:oban_chore_count, Chores.Greeter, 0}
    end

    test "broadcasts :retryable when a job fails with attempts left" do
      %{id: job_id} = job = insert_job!(Chores.Failing, %{})
      subscribe_job(job)
      Oban.resume_queue(queue: :default)

      assert {^job_id, pid} = await_job_started()
      assert_receive {:oban_chore_state, ^job_id, :executing}

      release_job(pid)

      assert_receive {:oban_chore_state, ^job_id, :retryable}
      assert_receive {:oban_chore_count, Chores.Failing, 0}
    end

    test "ignores jobs from workers that aren't registered chores" do
      job = insert_job!(PlainWorker, %{})
      subscribe_job(job)
      Oban.resume_queue(queue: :default)

      assert {_job_id, pid} = await_job_started()
      release_job(pid)

      refute_receive {:oban_chore_state, _, _}, 300
      refute_received {:oban_chore_count, _, _}
    end
  end

  defp subscribe_job(%Oban.Job{id: id}) do
    Phoenix.PubSub.subscribe(pubsub(), "oban_chore:status:#{id}")
    Phoenix.PubSub.subscribe(pubsub(), "oban_chore:logs:#{id}")
  end

  defp insert_completed!(worker, args) do
    worker.new(args)
    |> Ecto.Changeset.put_change(:state, "completed")
    |> Oban.insert!()
  end
end
