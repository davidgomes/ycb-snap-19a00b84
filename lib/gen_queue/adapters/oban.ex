defmodule GenQueue.Adapters.Oban do
  @moduledoc """
  An adapter for `GenQueue` to enable functionaility with `Oban`.
  """

  use GenQueue.JobAdapter

  alias GenQueue.Job

  @doc """
  Starts an `Oban` supervision tree named after the `GenQueue` module.

  Any options from the `GenQueue` config (except `:adapter`) are merged with the
  given `opts` and passed directly to `Oban.start_link/1`.
  """
  def start_link(gen_queue, opts \\ []) do
    gen_queue.config()
    |> Keyword.delete(:adapter)
    |> Keyword.merge(opts)
    |> Keyword.put_new(:name, gen_queue)
    |> Oban.start_link()
  end

  @doc """
  Push a `GenQueue.Job` for Oban to consume.

  Oban requires job args to be a map, so zero-arg jobs are enqueued with `%{}`
  and single-arg jobs must be given a map. Any adapter-specific `:config` given
  to the job (such as `:max_attempts`) is passed along to the worker.

  ## Parameters:
    * `gen_queue` - A `GenQueue` module
    * `job` - A `GenQueue.Job`

  ## Returns:
    * `{:ok, job}` if the operation was successful
    * `{:error, reason}` if there was an error
  """
  @spec handle_job(gen_queue :: GenQueue.t(), job :: GenQueue.Job.t()) ::
          {:ok, GenQueue.Job.t()} | {:error, any}
  def handle_job(gen_queue, %Job{args: []} = job) do
    handle_job(gen_queue, %{job | args: [%{}]})
  end

  def handle_job(gen_queue, %Job{args: [args]} = job) when is_map(args) do
    changeset = job.module.new(args, build_opts(job))

    case Oban.insert(gen_queue, changeset) do
      {:ok, _} -> {:ok, job}
      error -> error
    end
  end

  def handle_job(_gen_queue, _job) do
    {:error, :invalid_args}
  end

  defp build_opts(job) do
    (job.config || [])
    |> put_queue(job.queue)
    |> put_delay(job.delay)
  end

  defp put_queue(opts, nil), do: opts
  defp put_queue(opts, queue), do: Keyword.put(opts, :queue, queue)

  defp put_delay(opts, nil), do: opts
  defp put_delay(opts, %DateTime{} = date), do: Keyword.put(opts, :scheduled_at, date)

  defp put_delay(opts, offset) when is_integer(offset) do
    case round(offset / 1000) do
      seconds when seconds > 0 -> Keyword.put(opts, :schedule_in, seconds)
      _ -> opts
    end
  end
end
