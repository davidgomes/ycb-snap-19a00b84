defmodule GenQueue.Adapters.Oban do
  @moduledoc """
  An adapter for `GenQueue` to enable functionaility with `Oban`.
  """

  use GenQueue.JobAdapter

  alias GenQueue.Job

  @doc """
  `Oban` is not started by this adapter.

  Please refer to the `Oban` documentation for details on configuring and starting
  `Oban` within your supervision tree.
  """
  def start_link(_gen_queue, _opts) do
    :ignore
  end

  @doc """
  Push a `GenQueue.Job` for `Oban` to consume.

  The job module must implement the `Oban.Worker` behaviour. As `Oban` requires
  job args to be a map, zero-arg jobs are inserted with `%{}`, while jobs with a
  single map arg are inserted with that map. Any other args are rejected.

  Jobs without a queue are inserted into the queue configured by their worker.

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
         {:ok, oban_job} <- Oban.insert(job.module.new(args, build_opts(job))) do
      {:ok, %{job | queue: oban_job.queue}}
    end
  end

  defp build_args([]), do: {:ok, %{}}
  defp build_args([args]) when is_map(args), do: {:ok, args}
  defp build_args(args), do: {:error, {:invalid_args, args}}

  defp build_opts(%Job{queue: nil, delay: delay}), do: delay_opts(delay)
  defp build_opts(%Job{queue: queue, delay: delay}), do: [{:queue, queue} | delay_opts(delay)]

  defp delay_opts(nil), do: []
  defp delay_opts(%DateTime{} = scheduled_at), do: [scheduled_at: scheduled_at]
  defp delay_opts(offset) when is_integer(offset), do: [schedule_in: round(offset / 1000)]
end
