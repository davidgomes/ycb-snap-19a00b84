defmodule GenQueue.Adapters.Oban do
  @moduledoc """
  An adapter for `GenQueue` to enable functionaility with `Oban`.

  This adapter handles zero `Oban` related config. `Oban` must be configured
  and started as described in its own documentation.
  """

  use GenQueue.JobAdapter

  alias GenQueue.Job

  def start_link(_gen_queue, _opts \\ []) do
    :ignore
  end

  @doc """
  Push a `GenQueue.Job` for `Oban` to consume.

  The job module must `use Oban.Worker`. As `Oban` requires job args to be a map,
  jobs without args are enqueued with `%{}`, and jobs with a single map arg are
  enqueued with that map. Any other args will result in an error.

  Any `:config` provided with the job is passed through as `Oban.Job` options,
  such as `:max_attempts` or `:priority`.

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
    with {:ok, args} <- build_args(job),
         {:ok, _oban_job} <- job.module.new(args, build_opts(job)) |> Oban.insert() do
      {:ok, job}
    end
  end

  defp build_args(%Job{args: []}), do: {:ok, %{}}
  defp build_args(%Job{args: [args]}) when is_map(args), do: {:ok, args}

  defp build_args(%Job{args: args}) do
    {:error, %GenQueue.Error{message: "Oban requires job args to be a map, got: #{inspect(args)}"}}
  end

  defp build_opts(job) do
    (job.config || [])
    |> put_queue(job.queue)
    |> put_delay(job.delay)
  end

  defp put_queue(opts, nil), do: opts
  defp put_queue(opts, queue), do: Keyword.put(opts, :queue, to_string(queue))

  defp put_delay(opts, %DateTime{} = scheduled_at), do: Keyword.put(opts, :scheduled_at, scheduled_at)

  defp put_delay(opts, offset) when is_integer(offset) do
    Keyword.put(opts, :schedule_in, round(offset / 1000))
  end

  defp put_delay(opts, _delay), do: opts
end
