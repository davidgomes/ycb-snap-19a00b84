defmodule Oban.Console.Jobs do
  alias Oban.Console.View.Printer
  alias Oban.Console.Repo
  alias Oban.Console.Storage

  @states %{
    "1" => "available",
    "2" => "scheduled",
    "3" => "retryable",
    "4" => "executing",
    "5" => "completed",
    "6" => "discarded",
    "7" => "cancelled"
  }

  @in_progress_states ~w[available scheduled retryable executing]
  @failed_states ~w[cancelled discarded]

  def list(opts \\ []) do
    Repo.all_jobs(opts)
  end

  def show_list(opts \\ []) do
    headers = [:id, :worker, :state, :queue, :attempt, :inserted_at, :attempted_at, :scheduled_at]
    opts = if opts == [], do: Storage.get_last_jobs_opts(), else: opts

    limit = Keyword.get(opts, :limit, 20) || 20
    converted_states = convert_states(Keyword.get(opts, :states, [])) || []
    ids = ids_listed_before(opts)

    opts = Keyword.put(opts, :ids, ids)
    opts = Keyword.put(opts, :states, converted_states)
    opts = Keyword.put(opts, :limit, limit)

    response = list(opts)
    ids = Enum.map(response, fn job -> job.id end)

    Storage.set_last_jobs_ids(ids)
    Storage.set_last_jobs_opts(opts)
    Storage.add_job_filter_history(opts)

    filters =
      Enum.reject(opts, fn
        {_, nil} -> true
        {_, []} -> true
        {_, _} -> false
      end)

    current_time = Calendar.strftime(DateTime.utc_now(), "%Y-%m-%d %H:%M:%S")

    Oban.Console.View.Table.show(
      response,
      headers,
      "[#{current_time}] Rows: #{length(response)} Filters: #{inspect(filters)} Sorts: DESC attempted_at, DESC scheduled_at"
    )
  rescue
    e ->
      Printer.red(inspect(e)) |> IO.puts()
      Storage.set_last_jobs_opts([])

      show_list()
  end

  def clean_storage(), do: Storage.set_last_jobs_opts([])

  def debug_jobs([_ | _] = jobs_ids), do: Enum.each(jobs_ids, &debug_jobs/1)
  def debug_jobs([]), do: :ok

  def debug_jobs(job_id) when is_integer(job_id) do
    case Repo.get_job(job_id) do
      nil ->
        ["Job", job_id, "Job not found"] |> Printer.title() |> IO.puts()

      job ->
        ["Job", job_id] |> Printer.title() |> IO.puts()
        IO.inspect(job)
    end
  end

  def debug_jobs(job_id) do
    ["Debug", job_id, "Job ID is not valid"] |> Printer.title() |> IO.puts()
  end

  def retry_jobs([_ | _] = jobs_ids), do: Enum.each(jobs_ids, &retry_jobs/1)
  def retry_jobs([]), do: :ok

  def retry_jobs(job_id) when is_integer(job_id) do
    Repo.retry_job(job_id)
    ["Retried", job_id] |> Printer.title() |> IO.puts()
  end

  def retry_jobs(job_id) do
    ["Retry", job_id, "Job ID is not valid"] |> Printer.title() |> IO.puts()
  end

  def cancel_jobs([_ | _] = jobs_ids), do: Enum.each(jobs_ids, &cancel_jobs/1)
  def cancel_jobs([]), do: :ok

  def cancel_jobs(job_id) when is_integer(job_id) do
    Repo.cancel_job(job_id)
    ["Cancelled", job_id] |> Printer.title() |> IO.puts()
  end

  def cancel_jobs(job_id) do
    ["Cancel", job_id, "Job ID is not valid"] |> Printer.title() |> IO.puts()
  end

  defp ids_listed_before(opts) do
    case Keyword.get(opts, :ids, []) do
      nil -> []
      [0] -> Storage.get_last_jobs_ids()
      ids -> ids
    end
  end

  defp convert_states(states) do
    states
    |> Enum.map(fn
      "in_progress" -> @in_progress_states
      "failed" -> @failed_states
      state when state in ["1", "2", "3", "4", "5", "6", "7"] -> Map.get(@states, state)
      state -> state
    end)
    |> List.flatten()
  end
end
