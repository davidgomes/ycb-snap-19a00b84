defmodule Oban.Console.Jobs do
  alias Oban.Console.Repo
  alias Oban.Console.Storage
  alias Oban.Console.View.Printer
  alias Oban.Console.View.Table

  @headers [:id, :worker, :state, :queue, :attempt, :inserted_at]

  def list(opts \\ []) do
    jobs = Repo.jobs(opts)

    Storage.set_last_jobs_opts(opts)
    Storage.set_last_jobs_ids(Enum.map(jobs, & &1.id))

    jobs
  end

  def show_list(opts \\ []), do: opts |> list() |> Table.show(@headers, "Jobs")

  def cancel_jobs([_ | _] = ids), do: Enum.each(ids, &cancel_jobs/1)
  def cancel_jobs([]), do: :ok

  def cancel_jobs(id) when is_integer(id) do
    Repo.cancel_job(id)
    ["Cancelled", to_string(id)] |> Printer.title() |> IO.puts()
  end

  def cancel_jobs(id) do
    ["Cancel", inspect(id), "Job id is not valid"] |> Printer.title() |> IO.puts()
  end

  def retry_jobs([_ | _] = ids), do: Enum.each(ids, &retry_jobs/1)
  def retry_jobs([]), do: :ok

  def retry_jobs(id) when is_integer(id) do
    Repo.retry_job(id)
    ["Retried", to_string(id)] |> Printer.title() |> IO.puts()
  end

  def retry_jobs(id) do
    ["Retry", inspect(id), "Job id is not valid"] |> Printer.title() |> IO.puts()
  end
end
