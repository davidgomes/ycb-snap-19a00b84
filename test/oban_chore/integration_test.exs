defmodule ObanChore.IntegrationTest do
  use ExUnit.Case, async: false

  alias ObanChore.Test.Chores.{UniqueCleanup, UserBackfill}
  alias ObanChore.Test.{PubSub, Repo}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  describe "queries against a real database" do
    test "count_running/1 counts only active jobs for the given worker" do
      insert!(UserBackfill, %{user_id: 1})
      insert!(UserBackfill, %{user_id: 2}, schedule_in: 60)
      insert!(UniqueCleanup, %{scope: "all"})
      UserBackfill |> insert!(%{user_id: 3}) |> Oban.cancel_job()

      assert ObanChore.count_running(UserBackfill) == 2
      assert ObanChore.count_running(UniqueCleanup) == 1
    end

    test "running_with_args?/2 matches active jobs containing the given args" do
      insert!(UserBackfill, %{user_id: 1, reason: "Manual run"})

      assert ObanChore.running_with_args?(UserBackfill, %{user_id: 1})
      assert ObanChore.running_with_args?(UserBackfill, %{"user_id" => 1, reason: "Manual run"})
      refute ObanChore.running_with_args?(UserBackfill, %{user_id: 2})
      refute ObanChore.running_with_args?(UniqueCleanup, %{user_id: 1})
    end

    test "running_with_args?/2 ignores jobs that are no longer active" do
      UserBackfill |> insert!(%{user_id: 1}) |> Oban.cancel_job()

      refute ObanChore.running_with_args?(UserBackfill, %{user_id: 1})
    end

    test "list_active_jobs/1 returns the worker's active jobs with atom states" do
      %{id: available_id} = insert!(UserBackfill, %{user_id: 1})
      %{id: scheduled_id} = insert!(UserBackfill, %{user_id: 2}, schedule_in: 60)
      insert!(UniqueCleanup, %{scope: "all"})

      states =
        UserBackfill
        |> ObanChore.list_active_jobs()
        |> Map.new(&{&1.id, &1.state})

      assert states == %{available_id => :available, scheduled_id => :scheduled}
    end
  end

  describe "telemetry" do
    setup do
      start_supervised!({ObanChore.Plugin, chores: [UserBackfill], pubsub_server: PubSub})
      Phoenix.PubSub.subscribe(PubSub, "oban_chore:counts")
      :ok
    end

    test "executing a chore broadcasts its status, logs and running count" do
      %{id: job_id} = insert!(UserBackfill, %{user_id: 5})

      Phoenix.PubSub.subscribe(PubSub, "oban_chore:status:#{job_id}")
      Phoenix.PubSub.subscribe(PubSub, "oban_chore:logs:#{job_id}")

      assert %{success: 1} = Oban.drain_queue(queue: :default)

      assert_receive {:oban_chore_state, ^job_id, :executing}
      assert_receive {:oban_chore_log, ^job_id, "Backfilling user 5"}
      assert_receive {:oban_chore_state, ^job_id, :completed}
      assert_receive {:oban_chore_count, UserBackfill, count} when is_integer(count)
    end

    test "jobs for workers that are not chores are ignored" do
      %{id: job_id} = insert!(UniqueCleanup, %{scope: "all"})
      Phoenix.PubSub.subscribe(PubSub, "oban_chore:status:#{job_id}")

      assert %{success: 1} = Oban.drain_queue(queue: :default)

      refute_receive {:oban_chore_state, ^job_id, _}
      refute_receive {:oban_chore_count, UniqueCleanup, _}
    end
  end

  defp insert!(worker, args, opts \\ []) do
    args |> worker.new(opts) |> Oban.insert!()
  end
end
