defmodule GenQueue.Adapters.Oban do
  @moduledoc """
  An adapter for `GenQueue` to enable functionaility with `Oban`.
  """

  use GenQueue.JobAdapter

  alias GenQueue.Job

  @doc """
  Start an `Oban` supervision tree with the given options.

  Please refer to the `Oban` documentation for the available options.
  """
  @spec start_link(gen_queue :: GenQueue.t(), opts :: Keyword.t()) :: Supervisor.on_start()
  def start_link(_gen_queue, opts) do
    Oban.start_link(opts)
  end

  @doc """
  Push a `GenQueue.Job` for `Oban` to consume.

  The job module must be an `Oban.Worker`. As `Oban` requires job args to be a
  map, the job must have either a single map arg, or no args at all - in which
  case an empty map is used.

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

  def handle_job(_gen_queue, %Job{module: module, args: [args]} = job) when is_map(args) do
    changeset = module.new(args, build_opts(job))

    case Oban.insert(changeset) do
      {:ok, %Oban.Job{queue: queue}} -> {:ok, %{job | queue: queue}}
      error -> error
    end
  end

  def handle_job(_gen_queue, _job) do
    {:error, :invalid_args}
  end

  defp build_opts(job) do
    []
    |> put_queue(job.queue)
    |> put_delay(job.delay)
  end

  defp put_queue(opts, nil), do: opts
  defp put_queue(opts, queue), do: Keyword.put(opts, :queue, queue)

  defp put_delay(opts, nil), do: opts
  defp put_delay(opts, %DateTime{} = at), do: Keyword.put(opts, :scheduled_at, at)

  defp put_delay(opts, milliseconds) when is_integer(milliseconds) do
    at = DateTime.add(DateTime.utc_now(), milliseconds, :millisecond)
    Keyword.put(opts, :scheduled_at, at)
  end
end
