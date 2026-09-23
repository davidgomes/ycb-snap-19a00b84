defmodule GenQueue.Adapters.Oban do
  @moduledoc """
  An adapter for `GenQueue` to enable functionality with `Oban`.

  This adapter does not start or configure `Oban`. `Oban` must be started
  separately within your supervision tree.
  """

  use GenQueue.JobAdapter

  @doc """
  Push a `GenQueue.Job` for `Oban` to consume.

  Jobs without arguments are enqueued with an empty map, as `Oban` requires
  job args to be a map.

  ## Parameters:
    * `gen_queue` - A `GenQueue` module
    * `job` - A `GenQueue.Job`

  ## Returns:
    * `{:ok, job}` if the operation was successful
    * `{:error, reason}` if there was an error
  """
  @spec handle_job(gen_queue :: GenQueue.t(), job :: GenQueue.Job.t()) ::
          {:ok, GenQueue.Job.t()} | {:error, any}
  def handle_job(gen_queue, %GenQueue.Job{args: []} = job) do
    handle_job(gen_queue, %{job | args: [%{}]})
  end

  def handle_job(_gen_queue, %GenQueue.Job{args: [args]} = job) when is_map(args) do
    case args |> job.module.new(build_options(job)) |> Oban.insert() do
      {:ok, _} -> {:ok, job}
      {:error, _} = error -> error
    end
  end

  def handle_job(_gen_queue, %GenQueue.Job{}) do
    {:error, :invalid_args}
  end

  defp build_options(job) do
    []
    |> put_queue(job.queue)
    |> put_delay(job.delay)
  end

  defp put_queue(opts, nil), do: opts
  defp put_queue(opts, queue), do: Keyword.put(opts, :queue, queue)

  defp put_delay(opts, nil), do: opts
  defp put_delay(opts, %DateTime{} = at), do: Keyword.put(opts, :scheduled_at, at)

  defp put_delay(opts, delay) when is_integer(delay) and delay > 0 do
    Keyword.put(opts, :schedule_in, div(delay + 999, 1_000))
  end

  defp put_delay(opts, _delay), do: opts
end
