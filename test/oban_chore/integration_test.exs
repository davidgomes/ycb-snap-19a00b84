defmodule ObanChore.IntegrationTest do
  use ExUnit.Case, async: true

  import Ecto.Query

  alias Ecto.Adapters.SQL.Sandbox
  alias ObanChore.TestChores.{AccountCleanup, UserBackfill}
  alias ObanChore.TestRepo

  setup do
    owner = Sandbox.start_owner!(TestRepo)
    on_exit(fn -> Sandbox.stop_owner(owner) end)
  end

  describe "count_running/2" do
    test "counts the worker's available, scheduled and executing jobs" do
      insert_job!(UserBackfill, %{user_id: 1})
      insert_job!(UserBackfill, %{user_id: 2}, schedule_in: 60)
      UserBackfill |> insert_job!(%{user_id: 3}) |> put_state("executing")
      UserBackfill |> insert_job!(%{user_id: 4}) |> put_state("completed")
      UserBackfill |> insert_job!(%{user_id: 5}) |> put_state("discarded")
      insert_job!(AccountCleanup, %{account_id: 1})

      assert ObanChore.count_running(UserBackfill) == 3
      assert ObanChore.count_running(AccountCleanup) == 1
    end
  end

  describe "running_with_args?/3" do
    test "matches active jobs whose args contain the given args" do
      insert_job!(UserBackfill, %{user_id: 1, reason: "Refund"})

      assert ObanChore.running_with_args?(UserBackfill, %{user_id: 1})
      assert ObanChore.running_with_args?(UserBackfill, %{"user_id" => 1, "reason" => "Refund"})
      refute ObanChore.running_with_args?(UserBackfill, %{user_id: 2})
      refute ObanChore.running_with_args?(UserBackfill, %{user_id: 1, reason: "Other"})
      refute ObanChore.running_with_args?(AccountCleanup, %{user_id: 1})
    end

    test "ignores jobs that are no longer active" do
      UserBackfill |> insert_job!(%{user_id: 1}) |> put_state("completed")

      refute ObanChore.running_with_args?(UserBackfill, %{user_id: 1})
    end
  end

  describe "list_active_jobs/2" do
    test "returns the worker's active jobs with atom states" do
      available = insert_job!(UserBackfill, %{user_id: 1})
      scheduled = insert_job!(UserBackfill, %{user_id: 2}, schedule_in: 60)
      UserBackfill |> insert_job!(%{user_id: 3}) |> put_state("cancelled")
      insert_job!(AccountCleanup, %{account_id: 1})

      jobs =
        UserBackfill
        |> ObanChore.list_active_jobs()
        |> Enum.map(&{&1.id, &1.state})
        |> Enum.sort()

      assert jobs == [{available.id, :available}, {scheduled.id, :scheduled}]
    end
  end

  describe "ObanChore.Plugin.handle_telemetry/4" do
    setup do
      pubsub = __MODULE__.PubSub
      start_supervised!({Phoenix.PubSub, name: pubsub})

      config = %{
        oban_name: Oban,
        pubsub_server: pubsub,
        chores: [UserBackfill.__chore_info__()]
      }

      {:ok, pubsub: pubsub, config: config}
    end

    test "broadcasts the job state and the chore's active count", ctx do
      job = insert_job!(UserBackfill, %{user_id: 1}) |> put_state("completed")
      insert_job!(UserBackfill, %{user_id: 2})

      Phoenix.PubSub.subscribe(ctx.pubsub, "oban_chore:counts")
      Phoenix.PubSub.subscribe(ctx.pubsub, "oban_chore:status:#{job.id}")

      ObanChore.Plugin.handle_telemetry(
        [:oban, :job, :stop],
        %{},
        %{conf: Oban.config(), job: job},
        ctx.config
      )

      job_id = job.id
      assert_receive {:oban_chore_state, ^job_id, :completed}
      assert_receive {:oban_chore_count, UserBackfill, 1}
    end

    test "ignores other Oban instances and workers that aren't chores", ctx do
      job = insert_job!(UserBackfill, %{user_id: 1})
      other_job = insert_job!(AccountCleanup, %{account_id: 1})

      Phoenix.PubSub.subscribe(ctx.pubsub, "oban_chore:counts")

      ObanChore.Plugin.handle_telemetry(
        [:oban, :job, :start],
        %{},
        %{conf: %{name: OtherOban}, job: job},
        ctx.config
      )

      ObanChore.Plugin.handle_telemetry(
        [:oban, :job, :start],
        %{},
        %{conf: Oban.config(), job: other_job},
        ctx.config
      )

      refute_receive {:oban_chore_count, _, _}
    end
  end

  defp insert_job!(worker, args, opts \\ []) do
    args |> worker.new(opts) |> Oban.insert!()
  end

  defp put_state(%Oban.Job{id: id} = job, state) do
    {1, _} = TestRepo.update_all(where(Oban.Job, id: ^id), set: [state: state])
    %{job | state: state}
  end
end
