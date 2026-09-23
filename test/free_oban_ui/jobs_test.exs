defmodule FreeObanUi.JobsTest do
  use FreeObanUi.DataCase, async: false

  alias FreeObanUi.Jobs
  alias FreeObanUi.Workers.PingWorker

  test "lists, filters, cancels, and retries jobs" do
    {:ok, available} = enqueue("alpha", queue: "default")
    {:ok, mail} = enqueue("beta", queue: "mail")

    listing = Jobs.list_jobs(%{})
    assert Enum.map(listing.jobs, & &1.id) |> Enum.sort() == Enum.sort([available.id, mail.id])
    assert listing.counts["available"] == 2

    filtered = Jobs.list_jobs(%{"queue" => "mail"})
    assert Enum.map(filtered.jobs, & &1.id) == [mail.id]

    {:ok, cancelled} = Jobs.cancel_job(available)
    assert cancelled.state == "cancelled"

    {:ok, retried} = Jobs.retry_job(cancelled)
    assert retried.state == "available"

    {:ok, deleted} = Jobs.delete_job(mail)
    assert deleted.id == mail.id
    assert Jobs.get_job(mail.id) == nil
  end

  defp enqueue(message, opts) do
    %{message: message}
    |> PingWorker.new(opts)
    |> Oban.insert()
  end
end
