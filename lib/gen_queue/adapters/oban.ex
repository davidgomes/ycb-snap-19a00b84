defmodule GenQueue.Adapters.Oban do
  @moduledoc """
  An adapter for `GenQueue` to enable functionaility with `Oban`.

  This adapter does not start or configure `Oban` - it must be started
  separately as described in the `Oban` documentation.
  """

  use GenQueue.JobAdapter

  alias GenQueue.Job

  @doc """
  Push a `GenQueue.Job` for `Oban` to consume.

  The job module must `use Oban.Worker`. As `Oban` requires job args to be a
  map, zero-arg jobs are enqueued with `%{}`, and single-arg jobs must be
  given a map.

  Any `:config` provided with the job is passed to the worker's `new/2` as
  additional `Oban` job options (eg. `max_attempts` or `unique`).

  ## Parameters:
    * `gen_queue` - A `GenQueue` module
    * `job` - A `GenQueue.Job`

  ## Returns:
    * `{:ok, job}` if the operation was successful
    * `{:error, reason}` if there was an error
  """
  @spec handle_job(gen_queue :: GenQueue.t(), job :: GenQueue.Job.t()) ::
          {:ok, GenQueue.Job.t()} | {:error, any}
  def handle_job(_gen_queue, %Job{module: module} = job) do
    with {:ok, args} <- build_args(job.args),
         {:ok, oban_job} <- args |> module.new(build_opts(job)) |> Oban.insert() do
      {:ok, %{job | queue: oban_job.queue}}
    end
  end

  defp build_args([]), do: {:ok, %{}}
  defp build_args([args]) when is_map(args), do: {:ok, args}
  defp build_args(_args), do: {:error, :invalid_args}

  defp build_opts(job) do
    (job.config || [])
    |> put_queue(job.queue)
    |> put_delay(job.delay)
  end

  defp put_queue(opts, nil), do: opts
  defp put_queue(opts, queue), do: Keyword.put(opts, :queue, queue)

  defp put_delay(opts, nil), do: opts
  defp put_delay(opts, %DateTime{} = at), do: Keyword.put(opts, :scheduled_at, at)

  defp put_delay(opts, offset) when is_integer(offset) do
    Keyword.put(opts, :schedule_in, round(offset / 1000))
  end
end
