defmodule FreeObanUi.JobsTest do
  use FreeObanUi.DataCase, async: false

  alias FreeObanUi.Jobs

  test "lists, filters, cancels, and retries jobs" do
    {:ok, available} = insert_job(%{"kind" => "a"}, queue: "default")
    {:ok, other} = insert_job(%{"kind" => "b"}, queue: "mailers")

    ids = Jobs.list_jobs(%{}) |> Enum.map(& &1.id)
    assert available.id in ids
    assert other.id in ids

    queued = Jobs.list_jobs(%{"queue" => "mail"}) |> Enum.map(& &1.id)
    assert queued == [other.id]

    assert {:ok, cancelled} = Jobs.cancel_job(available.id)
    assert cancelled.state == "cancelled"

    assert {:ok, retried} = Jobs.retry_job(cancelled.id)
    assert retried.state == "available"
  end

  defp insert_job(args, opts) do
    args
    |> Oban.Job.new(Keyword.merge([worker: "FreeObanUi.Workers.Example"], opts))
    |> Oban.insert()
  end
end
