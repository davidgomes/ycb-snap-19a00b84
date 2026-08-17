defmodule FreeObanUi.JobsTest do
  use FreeObanUi.DataCase, async: true

  alias FreeObanUi.Jobs

  defmodule FakeWorker do
    use Oban.Worker, queue: :default

    @impl Oban.Worker
    def perform(_job), do: :ok
  end

  defp insert_job!(opts) do
    opts
    |> Keyword.new()
    |> Keyword.put_new(:worker, FakeWorker)
    |> then(&Oban.Job.new(%{}, &1))
    |> Repo.insert!()
  end

  describe "list_jobs/1" do
    test "returns all jobs ordered by id descending" do
      job1 = insert_job!(%{})
      job2 = insert_job!(%{})

      assert [%{id: id2}, %{id: id1}] = Jobs.list_jobs()
      assert id1 == job1.id
      assert id2 == job2.id
    end

    test "filters by state" do
      insert_job!(%{state: "available"})
      completed = insert_job!(%{state: "completed"})

      assert [%{id: id}] = Jobs.list_jobs(%{state: "completed"})
      assert id == completed.id
    end

    test "filters by queue" do
      insert_job!(%{queue: "default"})
      mailers = insert_job!(%{queue: "mailers"})

      assert [%{id: id}] = Jobs.list_jobs(%{queue: "mailers"})
      assert id == mailers.id
    end
  end

  test "count_by_state/0 tallies jobs for every known state" do
    insert_job!(%{state: "available"})
    insert_job!(%{state: "available"})
    insert_job!(%{state: "completed"})

    counts = Jobs.count_by_state()

    assert counts["available"] == 2
    assert counts["completed"] == 1
    assert counts["cancelled"] == 0
  end

  test "list_queues/0 returns distinct queue names" do
    insert_job!(%{queue: "default"})
    insert_job!(%{queue: "default"})
    insert_job!(%{queue: "mailers"})

    assert Jobs.list_queues() == ["default", "mailers"]
  end

  test "retry_job/1 makes a discarded job available again" do
    job = insert_job!(%{state: "discarded", max_attempts: 1, attempt: 1})

    assert :ok = Jobs.retry_job(job)
    assert Jobs.get_job!(job.id).state == "available"
  end

  test "cancel_job/1 marks a scheduled job as cancelled" do
    job = insert_job!(%{state: "scheduled", scheduled_at: DateTime.utc_now()})

    assert :ok = Jobs.cancel_job(job)
    assert Jobs.get_job!(job.id).state == "cancelled"
  end

  test "delete_job/1 removes the job" do
    job = insert_job!(%{})

    assert {:ok, _} = Jobs.delete_job(job)
    assert_raise Ecto.NoResultsError, fn -> Jobs.get_job!(job.id) end
  end
end
