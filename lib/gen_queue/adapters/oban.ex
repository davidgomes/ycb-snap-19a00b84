defmodule GenQueue.Adapters.Oban do
  @moduledoc """
  An adapter for `GenQueue` to enable functionaility with `Oban`.
  """

  use GenQueue.JobAdapter

  @doc false
  def start_link(_gen_queue, _opts) do
    :ignore
  end

  @doc """
  Push a `GenQueue.Job` for `Oban` to consume.

  ## Parameters:
    * `gen_queue` - A `GenQueue` module
    * `job` - A `GenQueue.Job`

  ## Returns:
    * `{:ok, %Oban.Job{}}` if the operation was successful
    * `{:error, reason}` if there was an error
  """
  @spec handle_job(gen_queue :: GenQueue.t(), job :: GenQueue.Job.t()) ::
          {:ok, Oban.Job.t()} | {:error, any()}
  def handle_job(_gen_queue, %GenQueue.Job{module: module} = job) do
    job
    |> build_args()
    |> module.new(build_opts(job))
    |> Oban.insert()
  end

  defp build_args(%GenQueue.Job{args: []}), do: %{}
  defp build_args(%GenQueue.Job{args: [%{} = args]}), do: args
  defp build_args(%GenQueue.Job{args: %{} = args}), do: args

  defp build_opts(%GenQueue.Job{queue: queue, delay: delay}) do
    []
    |> put_queue(queue)
    |> put_delay(delay)
  end

  defp put_queue(opts, nil), do: opts
  defp put_queue(opts, queue), do: Keyword.put(opts, :queue, to_string(queue))

  defp put_delay(opts, nil), do: opts
  defp put_delay(opts, %DateTime{} = at), do: Keyword.put(opts, :scheduled_at, at)

  defp put_delay(opts, ms) when is_integer(ms),
    do: Keyword.put(opts, :schedule_in, div(ms, 1000))
end
