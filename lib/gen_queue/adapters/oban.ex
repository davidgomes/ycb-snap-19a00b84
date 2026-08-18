defmodule GenQueue.Adapters.Oban do
  @moduledoc """
  An adapter for `GenQueue` to enable functionaility with `Oban`.

  `Oban` is not started with your application. Instead, the `GenQueue` module
  using this adapter must be placed within your supervision tree. Any `Oban`
  option can be placed alongside the `:adapter` option of your `GenQueue`
  config, and is passed through to `Oban` untouched.

      config :my_app, Enqueuer, [
        adapter: GenQueue.Adapters.Oban,
        repo: MyApp.Repo,
        queues: [default: 10]
      ]

  This includes the `:name` used to register the `Oban` supervisor, which
  jobs are pushed to. It defaults to `Oban` - the same default `Oban` itself
  uses.
  """

  use GenQueue.JobAdapter

  alias GenQueue.Job

  @doc """
  Start an `Oban` supervisor using the config of a `GenQueue` module.

  Options passed to `start_link/2` take precedence over the config of the
  `GenQueue` module. Please refer to the `Oban` documentation for the full
  list of available options.

  ## Parameters:
    * `gen_queue` - A `GenQueue` module
    * `opts` - `Oban` options

  ## Returns:
    * `{:ok, pid}` if the supervisor was started
    * `{:error, reason}` if there was an error
  """
  @spec start_link(gen_queue :: GenQueue.t(), opts :: Keyword.t()) :: GenServer.on_start()
  def start_link(gen_queue, opts) do
    gen_queue
    |> build_config(opts)
    |> Oban.start_link()
  end

  @doc """
  Push a `GenQueue.Job` for `Oban` to consume.

  The job module must `use Oban.Worker`. Since `Oban` requires jobs to be
  enqueued with a map of args, jobs pushed without any args default to `%{}`.

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

  def handle_job(gen_queue, %Job{module: module, args: [args]} = job) do
    changeset = module.new(args, build_options(job))

    case Oban.insert(oban_name(gen_queue), changeset) do
      {:ok, _oban_job} -> {:ok, job}
      error -> error
    end
  end

  defp build_config(gen_queue, opts) do
    gen_queue.config()
    |> Keyword.merge(opts)
    |> Keyword.delete(:adapter)
  end

  defp oban_name(gen_queue) do
    Keyword.get(gen_queue.config(), :name, Oban)
  end

  defp build_options(%Job{} = job) do
    []
    |> put_queue(job)
    |> put_schedule(job)
  end

  defp put_queue(opts, %Job{queue: nil}), do: opts
  defp put_queue(opts, %Job{queue: queue}), do: Keyword.put(opts, :queue, queue)

  defp put_schedule(opts, %Job{delay: %DateTime{} = delay}) do
    Keyword.put(opts, :scheduled_at, delay)
  end

  defp put_schedule(opts, %Job{delay: delay}) when is_integer(delay) do
    Keyword.put(opts, :schedule_in, round(delay / 1_000))
  end

  defp put_schedule(opts, %Job{}), do: opts
end
