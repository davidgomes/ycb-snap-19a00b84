defmodule GenQueue.Adapters.Oban do
  @moduledoc """
  An adapter for `GenQueue` to enable functionaility with `Oban`.
  """

  use GenQueue.JobAdapter

  alias GenQueue.Job

  @doc """
  Start an `Oban` supervisor named after the given `GenQueue`.

  This adapter handles zero `Oban` related config. Please refer to the `Oban`
  documentation for details on the options available.

  ## Parameters:
    * `gen_queue` - A `GenQueue` module
    * `opts` - Options for `Oban`

  ## Returns:
    * `{:ok, pid}` if the operation was successful
    * `{:error, reason}` if there was an error
  """
  @spec start_link(gen_queue :: GenQueue.t(), opts :: Keyword.t()) :: Supervisor.on_start()
  def start_link(gen_queue, opts \\ []) do
    opts
    |> Keyword.merge(name: gen_queue)
    |> Oban.start_link()
  end

  @doc """
  Push a `GenQueue.Job` for Oban to consume.

  Job modules must `use Oban.Worker`. Since `Oban` requires job args to be a
  map, jobs pushed without args are given an empty map.

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
    case Oban.insert(gen_queue, changeset(job, args)) do
      {:ok, _oban_job} -> {:ok, job}
      error -> error
    end
  end

  def handle_job(_gen_queue, _job) do
    {:error, :invalid_args}
  end

  defp changeset(%Job{module: module} = job, args) do
    module.new(args, job_opts(job))
  end

  defp job_opts(job) do
    []
    |> put_queue(job)
    |> put_schedule(job)
  end

  defp put_queue(opts, %Job{queue: nil}), do: opts
  defp put_queue(opts, %Job{queue: queue}), do: Keyword.put(opts, :queue, queue)

  defp put_schedule(opts, %Job{delay: nil}), do: opts

  defp put_schedule(opts, %Job{delay: %DateTime{} = delay}) do
    Keyword.put(opts, :scheduled_at, delay)
  end

  defp put_schedule(opts, %Job{delay: delay}) when is_integer(delay) do
    Keyword.put(opts, :scheduled_at, DateTime.add(DateTime.utc_now(), delay, :millisecond))
  end
end
