defmodule FreeObanUi.JobsTest do
  use FreeObanUi.DataCase, async: true

  alias FreeObanUi.Jobs

  defp insert_job(attrs) do
    %{}
    |> Oban.Job.new(worker: "MyApp.SomeWorker", queue: "default")
    |> Ecto.Changeset.change(attrs)
    |> Repo.insert!()
  end

  test "list_jobs/1 returns newest jobs first, optionally filtered by state" do
    a = insert_job(%{state: "available"})
    c = insert_job(%{state: "completed"})

    assert [%{id: c_id}, %{id: a_id}] = Jobs.list_jobs()
    assert {c_id, a_id} == {c.id, a.id}
    assert [%{id: ^a_id}] = Jobs.list_jobs(state: "available")
    assert Jobs.list_jobs(state: "bogus") |> length() == 2
  end

  test "count_by_state/0 includes every state" do
    insert_job(%{state: "discarded"})
    insert_job(%{state: "discarded"})

    counts = Jobs.count_by_state()
    assert counts["discarded"] == 2
    assert counts["available"] == 0
    assert Map.keys(counts) |> Enum.sort() == Enum.sort(Jobs.states())
  end

  test "retry, cancel and delete update the job" do
    job = insert_job(%{state: "discarded"})
    assert :ok = Jobs.retry_job(job)
    assert Jobs.get_job(job.id).state == "available"

    assert :ok = Jobs.cancel_job(job)
    assert Jobs.get_job(job.id).state == "cancelled"

    assert :ok = Jobs.delete_job(job)
    refute Jobs.get_job(job.id)
  end
end
