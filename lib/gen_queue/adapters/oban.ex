defmodule GenQueue.Adapters.Oban do
  @moduledoc """
  An adapter for `GenQueue` to enable functionaility with `Oban`.
  """

  use GenQueue.JobAdapter

  alias GenQueue.Job

  @doc """
  Starts `Oban` with the given options.

  The options are passed as-is to `Oban.start_link/1`. Please refer to the
  `Oban` documentation for details on the available options.
  """
  @spec start_link(gen_queue :: GenQueue.t(), opts :: Keyword.t()) :: Supervisor.on_start()
  def start_link(_gen_queue, opts) do
    Oban.start_link(opts)
  end

  @doc """
  Push a `GenQueue.Job` for `Oban` to consume.

  The job module must `use Oban.Worker`. As `Oban` requires job args to be a
  map, jobs must be pushed with either no args (enqueued as `%{}`) or a single
  map. Integer delays are treated as milliseconds.

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
    changeset = job.module.new(build_args(job), build_opts(job))

    case Oban.insert(changeset) do
      {:ok, _} -> {:ok, job}
      error -> error
    end
  end

  defp build_args(%Job{args: []}), do: %{}
  defp build_args(%Job{args: [args]}) when is_map(args), do: args

  defp build_args(%Job{args: args}) do
    raise ArgumentError,
          "expected Oban job args to be empty or a single map, got: #{inspect(args)}"
  end

  defp build_opts(%Job{} = job) do
    []
    |> put_queue(job.queue)
    |> put_delay(job.delay)
  end

  defp put_queue(opts, nil), do: opts
  defp put_queue(opts, queue), do: Keyword.put(opts, :queue, queue)

  defp put_delay(opts, nil), do: opts
  defp put_delay(opts, %DateTime{} = at), do: Keyword.put(opts, :scheduled_at, at)

  defp put_delay(opts, delay) when is_integer(delay) do
    Keyword.put(opts, :scheduled_at, DateTime.add(DateTime.utc_now(), delay, :millisecond))
  end
end
