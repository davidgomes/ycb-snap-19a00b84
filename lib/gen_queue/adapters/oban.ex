defmodule GenQueue.Adapters.Oban do
  @moduledoc """
  An adapter for `GenQueue` to enable functionaility with `Oban`.
  """

  use GenQueue.JobAdapter

  alias GenQueue.Job

  @doc """
  Start an `Oban` supervision tree for a `GenQueue` module.

  Any config for the `GenQueue` module (other than `:adapter`) is merged with
  the given options and passed directly to `Oban.start_link/1`.
  """
  @spec start_link(gen_queue :: GenQueue.t(), opts :: Keyword.t()) :: Supervisor.on_start()
  def start_link(gen_queue, opts \\ []) do
    gen_queue.config()
    |> Keyword.delete(:adapter)
    |> Keyword.merge(opts)
    |> Oban.start_link()
  end

  @doc """
  Push a `GenQueue.Job` for `Oban` to consume.

  The job module must be an `Oban.Worker`. As `Oban` jobs accept a single map of
  args, the job args must either be empty (which defaults to `%{}`) or contain
  a single map.

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
         {:ok, _oban_job} <- Oban.insert(job.module.new(args, build_opts(job))) do
      {:ok, job}
    end
  end

  defp build_args([]), do: {:ok, %{}}
  defp build_args([args]) when is_map(args), do: {:ok, args}
  defp build_args(args), do: {:error, {:invalid_args, args}}

  defp build_opts(job) do
    []
    |> put_queue(job.queue)
    |> put_schedule(job.delay)
  end

  defp put_queue(opts, nil), do: opts
  defp put_queue(opts, queue), do: Keyword.put(opts, :queue, queue)

  defp put_schedule(opts, %DateTime{} = date), do: Keyword.put(opts, :scheduled_at, date)

  defp put_schedule(opts, delay) when is_integer(delay) do
    Keyword.put(opts, :scheduled_at, DateTime.add(DateTime.utc_now(), delay, :millisecond))
  end

  defp put_schedule(opts, _), do: opts
end
