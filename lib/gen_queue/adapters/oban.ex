defmodule GenQueue.Adapters.Oban do
  @moduledoc """
  An adapter for `GenQueue` to enable functionaility with `Oban`.

  This adapter does not start or configure `Oban`. Please refer to the `Oban`
  documentation for details on how to add it to your supervision tree.
  """

  use GenQueue.JobAdapter

  alias GenQueue.Job

  @doc """
  Push a `GenQueue.Job` for `Oban` to consume.

  Zero-arg jobs are enqueued with `%{}` as their args, as per `Oban` requirements.
  Any `:config` provided with the job is passed as options to `Oban.Worker.new/2`.

  ## Parameters:
    * `gen_queue` - A `GenQueue` module
    * `job` - A `GenQueue.Job`

  ## Returns:
    * `{:ok, job}` if the operation was successful
    * `{:error, reason}` if there was an error
  """
  @spec handle_job(gen_queue :: GenQueue.t(), job :: GenQueue.Job.t()) ::
          {:ok, GenQueue.Job.t()} | {:error, any}
  def handle_job(_gen_queue, %Job{} = job) do
    with {:ok, args} <- build_args(job.args),
         {:ok, _} <- job.module.new(args, build_opts(job)) |> Oban.insert() do
      {:ok, job}
    end
  end

  defp build_args([]), do: {:ok, %{}}
  defp build_args([args]) when is_map(args), do: {:ok, args}
  defp build_args(_), do: {:error, :invalid_args}

  defp build_opts(%Job{queue: queue, delay: delay, config: config}) do
    (config || [])
    |> put_queue(queue)
    |> put_delay(delay)
  end

  defp put_queue(opts, nil), do: opts
  defp put_queue(opts, queue), do: Keyword.put(opts, :queue, queue)

  defp put_delay(opts, nil), do: opts
  defp put_delay(opts, %DateTime{} = at), do: Keyword.put(opts, :scheduled_at, at)

  defp put_delay(opts, offset) when is_integer(offset) do
    Keyword.put(opts, :schedule_in, round(offset / 1000))
  end
end
