defmodule FreeObanUi.JobsTest do
  use FreeObanUi.DataCase, async: true

  alias FreeObanUi.Jobs
  alias FreeObanUi.Repo
  alias FreeObanUi.Workers.ExampleWorker

  defp insert_job!(args, opts \\ []) do
    args |> ExampleWorker.new(opts) |> Oban.insert!()
  end

  defp set_state!(job, state) do
    job |> Ecto.Changeset.change(state: state) |> Repo.update!()
  end

  describe "list_jobs/2 and count_jobs/1" do
    test "returns every job when no filters are given" do
      job_a = insert_job!(%{id: 1})
      job_b = insert_job!(%{id: 2})

      ids = Jobs.list_jobs() |> Enum.map(& &1.id) |> Enum.sort()

      assert ids == Enum.sort([job_a.id, job_b.id])
      assert Jobs.count_jobs() == 2
    end

    test "filters by state" do
      available = insert_job!(%{id: 1})
      completed = insert_job!(%{id: 2}) |> set_state!("completed")

      assert Jobs.list_jobs(%{state: "completed"}) == [completed]
      assert Jobs.count_jobs(%{state: "completed"}) == 1

      assert Jobs.list_jobs(%{state: "all"}) |> Enum.map(& &1.id) |> Enum.sort() ==
               Enum.sort([available.id, completed.id])
    end

    test "filters by queue" do
      default_job = insert_job!(%{id: 1}, queue: :default)
      _mailer_job = insert_job!(%{id: 2}, queue: :mailers)

      assert Jobs.list_jobs(%{queue: "default"}) == [default_job]
      assert Jobs.count_jobs(%{queue: "default"}) == 1
    end

    test "paginates results" do
      jobs = for id <- 1..3, do: insert_job!(%{id: id})
      expected_ids = jobs |> Enum.map(& &1.id) |> Enum.sort(:desc)

      page_size = Jobs.page_size()
      assert length(Jobs.list_jobs(%{}, page: 1)) == min(3, page_size)

      [first_id | _] = Jobs.list_jobs(%{}, page: 1) |> Enum.map(& &1.id)
      assert first_id == List.first(expected_ids)
    end
  end

  test "queues/0 returns the distinct queues in use" do
    insert_job!(%{id: 1}, queue: :default)
    insert_job!(%{id: 2}, queue: :mailers)

    assert Jobs.queues() == ["default", "mailers"]
  end

  test "cancel_job/1 marks an available job as cancelled" do
    job = insert_job!(%{id: 1})

    assert :ok = Jobs.cancel_job(job.id)
    assert Repo.get!(Oban.Job, job.id).state == "cancelled"
  end

  test "retry_job/1 marks a discarded job as available" do
    job = insert_job!(%{id: 1}) |> set_state!("discarded")

    assert :ok = Jobs.retry_job(job.id)
    assert Repo.get!(Oban.Job, job.id).state == "available"
  end
end
