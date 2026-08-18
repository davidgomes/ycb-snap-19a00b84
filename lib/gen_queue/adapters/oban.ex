defmodule GenQueue.Adapters.Oban do
  @moduledoc """
  An adapter for `GenQueue` to enable functionality with `Oban`.

  ## Configuration

  This adapter handles zero `Oban` related config. Please refer to the `Oban`
  documentation for the available options. Any config provided for our
  `GenQueue` module is passed - untouched - to `Oban` when it is started.

      config :my_app, Enqueuer, [
        adapter: GenQueue.Adapters.Oban,
        repo: MyApp.Repo,
        queues: [default: 10]
      ]

      defmodule Enqueuer do
        use GenQueue, otp_app: :my_app
      end

  `Oban` is not started with the application, so our `GenQueue` module must be
  added to a supervision tree.

      children = [
        supervisor(Enqueuer, []),
      ]

  ## Jobs

  Jobs are modules that `use Oban.Worker` with the relevant configuration.

      defmodule MyJob do
        use Oban.Worker, queue: "events", max_attempts: 10

        @impl Oban.Worker
        def perform(args, _job) do
          IO.inspect(args)
        end
      end

  ## Enqueuing jobs

  Jobs are enqueued with a single map of args - as required by `Oban`. Zero-arg
  jobs are enqueued with `%{}`.

      # Push MyJob to its default queue with %{} args
      {:ok, job} = Enqueuer.push(MyJob)

      # Push MyJob to its default queue with %{"foo" => "bar"} args
      {:ok, job} = Enqueuer.push({MyJob, %{"foo" => "bar"}})

      # Push MyJob to the "foo" queue
      {:ok, job} = Enqueuer.push({MyJob, %{"foo" => "bar"}}, [queue: "foo"])

      # Schedule MyJob in 10 seconds
      {:ok, job} = Enqueuer.push({MyJob, %{"foo" => "bar"}}, [delay: 10_000])

      # Schedule MyJob at a specific time
      {:ok, job} = Enqueuer.push({MyJob, %{"foo" => "bar"}}, [delay: DateTime.utc_now()])

  Any further job options - such as `:max_attempts` or `:unique` - can be given
  with the `:config` option. Please refer to `Oban.Job.new/2` for the available
  options.

      {:ok, job} = Enqueuer.push(MyJob, [config: [max_attempts: 5]])
  """

  use GenQueue.JobAdapter

  @doc """
  Starts an `Oban` supervision tree for a `GenQueue` module.

  The config for the `GenQueue` module - merged with any options provided - is
  passed directly to `Oban.start_link/1`.
  """
  @spec start_link(GenQueue.t(), Keyword.t()) :: Supervisor.on_start()
  def start_link(gen_queue, opts) do
    gen_queue.config()
    |> Keyword.merge(opts)
    |> Keyword.delete(:adapter)
    |> Oban.start_link()
  end

  @doc """
  Pushes a job to `Oban`.
  """
  @spec handle_job(GenQueue.t(), GenQueue.Job.t()) :: {:ok, GenQueue.Job.t()} | {:error, any}
  def handle_job(_gen_queue, %GenQueue.Job{} = job) do
    case Oban.insert(build_changeset(job)) do
      {:ok, %Oban.Job{}} -> {:ok, job}
      {:error, error} -> {:error, error}
    end
  end

  defp build_changeset(%GenQueue.Job{module: module} = job) do
    module.new(build_args(job), build_opts(job))
  end

  defp build_args(%GenQueue.Job{args: []}), do: %{}

  defp build_args(%GenQueue.Job{args: [args]}) when is_map(args), do: args

  defp build_args(%GenQueue.Job{args: args}) do
    raise ArgumentError, "Oban jobs must be enqueued with a single map of args - got: #{inspect(args)}"
  end

  defp build_opts(%GenQueue.Job{} = job) do
    (job.config || [])
    |> put_queue(job.queue)
    |> put_schedule(job.delay)
  end

  defp put_queue(opts, nil), do: opts

  defp put_queue(opts, queue), do: Keyword.put(opts, :queue, queue)

  defp put_schedule(opts, nil), do: opts

  defp put_schedule(opts, %DateTime{} = date) do
    Keyword.put(opts, :schedule_in, DateTime.diff(date, DateTime.utc_now()))
  end

  defp put_schedule(opts, delay) when is_integer(delay) do
    Keyword.put(opts, :schedule_in, System.convert_time_unit(delay, :millisecond, :second))
  end
end
