defmodule ObanChore.IntegrationTest do
  use ObanChore.DataCase, async: false

  alias ObanChore.TestChores.{FailingChore, UniqueReindex, UserBackfill}

  describe "count_running/2" do
    test "counts available, scheduled and executing jobs for the worker" do
      insert_job!(UserBackfill, %{user_id: 1}, "available")
      insert_job!(UserBackfill, %{user_id: 2}, "scheduled")
      insert_job!(UserBackfill, %{user_id: 3}, "executing")
      insert_job!(UserBackfill, %{user_id: 4}, "completed")
      insert_job!(UserBackfill, %{user_id: 5}, "discarded")
      insert_job!(UniqueReindex, %{index: "users"}, "available")

      assert ObanChore.count_running(UserBackfill) == 3
      assert ObanChore.count_running(UniqueReindex) == 1
      assert ObanChore.count_running(FailingChore) == 0
    end
  end

  describe "running_with_args?/3" do
    test "matches active jobs whose args contain the given args" do
      insert_job!(UserBackfill, %{user_id: 1, reason: "manual"})

      assert ObanChore.running_with_args?(UserBackfill, %{user_id: 1})
      assert ObanChore.running_with_args?(UserBackfill, %{"user_id" => 1, "reason" => "manual"})
      refute ObanChore.running_with_args?(UserBackfill, %{user_id: 2})
      refute ObanChore.running_with_args?(UserBackfill, %{user_id: 1, reason: "other"})
      refute ObanChore.running_with_args?(UniqueReindex, %{user_id: 1})
    end

    test "ignores jobs that are no longer active" do
      insert_job!(UserBackfill, %{user_id: 1}, "completed")
      insert_job!(UserBackfill, %{user_id: 1}, "cancelled")

      refute ObanChore.running_with_args?(UserBackfill, %{user_id: 1})
    end
  end

  describe "list_active_jobs/2" do
    test "returns the worker's active jobs with atom states" do
      available = insert_job!(UserBackfill, %{user_id: 1}, "available")
      scheduled = insert_job!(UserBackfill, %{user_id: 2}, "scheduled")
      insert_job!(UserBackfill, %{user_id: 3}, "completed")
      insert_job!(UniqueReindex, %{index: "users"}, "available")

      jobs = ObanChore.list_active_jobs(UserBackfill)

      assert jobs |> Enum.map(&{&1.id, &1.state}) |> Enum.sort() ==
               Enum.sort([{available.id, :available}, {scheduled.id, :scheduled}])
    end
  end

  describe "plugin telemetry" do
    setup do
      pid =
        start_supervised!(
          {ObanChore.Plugin,
           chores: [UserBackfill, FailingChore], pubsub_server: ObanChore.TestPubSub}
        )

      _ = :sys.get_state(pid)
      Phoenix.PubSub.subscribe(ObanChore.TestPubSub, "oban_chore:counts")
      :ok
    end

    test "broadcasts status, logs and counts while a chore executes" do
      job = insert_job!(UserBackfill, %{user_id: 42})
      subscribe_to_job(job)

      assert :ok = execute_job(job)

      assert_receive {:oban_chore_state, id, :executing} when id == job.id
      assert_receive {:oban_chore_log, id, "Backfilling user 42"} when id == job.id
      assert_receive {:oban_chore_state, id, :completed} when id == job.id
      assert_receive {:oban_chore_count, UserBackfill, 1}
    end

    test "broadcasts a retryable state when a chore fails" do
      job = insert_job!(FailingChore, %{})
      subscribe_to_job(job)

      assert {:error, "boom"} = execute_job(job)

      assert_receive {:oban_chore_state, id, :executing} when id == job.id
      assert_receive {:oban_chore_state, id, :retryable} when id == job.id
    end

    test "ignores workers that aren't registered chores" do
      job = insert_job!(UniqueReindex, %{index: "users"})
      subscribe_to_job(job)

      assert :ok = execute_job(job)

      refute_receive {:oban_chore_state, _, _}
      refute_receive {:oban_chore_count, UniqueReindex, _}
    end
  end

  defp subscribe_to_job(job) do
    Phoenix.PubSub.subscribe(ObanChore.TestPubSub, "oban_chore:status:#{job.id}")
    Phoenix.PubSub.subscribe(ObanChore.TestPubSub, "oban_chore:logs:#{job.id}")
  end
end
