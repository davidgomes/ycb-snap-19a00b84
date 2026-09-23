defmodule ObanChore.IntegrationTest do
  use ObanChore.DataCase, async: false

  alias ObanChore.Test.{BackfillChore, UniqueChore}

  defp insert_job!(worker, args, opts \\ []) do
    {:ok, job} = Oban.insert(worker.new(args, opts))
    job
  end

  defp set_state!(job, state) do
    job |> Ecto.Changeset.change(state: state) |> TestRepo.update!()
  end

  describe "count_running/2" do
    test "counts only active jobs for the given worker" do
      insert_job!(BackfillChore, %{user_id: 1})
      insert_job!(BackfillChore, %{user_id: 2}, schedule_in: 60)
      insert_job!(UniqueChore, %{account_id: 1})

      BackfillChore |> insert_job!(%{user_id: 3}) |> set_state!("completed")

      assert ObanChore.count_running(BackfillChore) == 2
      assert ObanChore.count_running(UniqueChore) == 1
    end
  end

  describe "running_with_args?/3" do
    test "matches active jobs whose args contain the given args" do
      insert_job!(BackfillChore, %{user_id: 1, reason: "fix"})

      assert ObanChore.running_with_args?(BackfillChore, %{user_id: 1})
      assert ObanChore.running_with_args?(BackfillChore, %{"user_id" => 1, "reason" => "fix"})
      refute ObanChore.running_with_args?(BackfillChore, %{user_id: 2})
      refute ObanChore.running_with_args?(UniqueChore, %{user_id: 1})
    end

    test "ignores jobs that are no longer active" do
      BackfillChore |> insert_job!(%{user_id: 1}) |> set_state!("discarded")

      refute ObanChore.running_with_args?(BackfillChore, %{user_id: 1})
    end
  end

  describe "list_active_jobs/2" do
    test "returns active jobs with atom states" do
      %{id: available_id} = insert_job!(BackfillChore, %{user_id: 1})
      %{id: scheduled_id} = insert_job!(BackfillChore, %{user_id: 2}, schedule_in: 60)
      insert_job!(UniqueChore, %{account_id: 1})

      jobs = ObanChore.list_active_jobs(BackfillChore)

      assert jobs |> Enum.map(&{&1.id, &1.state}) |> Enum.sort() ==
               [{available_id, :available}, {scheduled_id, :scheduled}]
    end
  end

  describe "worker execution" do
    setup do
      Application.put_env(:oban_chore, :pubsub_server, ObanChore.Test.PubSub)
      :ok
    end

    test "logs from perform/1 are broadcast to the job's log topic" do
      job = BackfillChore |> insert_job!(%{user_id: 42}) |> TestRepo.reload!()
      Phoenix.PubSub.subscribe(ObanChore.Test.PubSub, "oban_chore:logs:#{job.id}")

      assert :ok = BackfillChore.perform(job)

      job_id = job.id
      assert_receive {:oban_chore_log, ^job_id, "Backfilling user 42"}
    end
  end
end
