defmodule ObanDoctor.Plugins.QueueMetrics do
  @moduledoc """
  Monitors queue depth and job counts across Oban queues.

  ## As Oban Plugin

  Add to your Oban config for scheduled telemetry emission:

      config :my_app, Oban,
        plugins: [
          {ObanDoctor.Plugins.QueueMetrics, interval: :timer.minutes(5)}
        ]

  The plugin automatically uses your Oban instance's configuration (repo, prefix,
  queues, limits). Only the leader node (via `Oban.Peer`) executes the scheduled
  check, ensuring metrics are emitted once across your cluster.

  ### Plugin Options

    * `:interval` - How often to emit telemetry in ms (default: 5 minutes)
    * `:queues` - Filter to specific queues (default: all configured queues)

  ### Telemetry

  Emits `[:oban_doctor, :queue, :metrics]` with the same data as `metrics/2`:

      :telemetry.attach("my-handler", [:oban_doctor, :queue, :metrics], fn _event, measurements, metadata, _config ->
        # measurements = %{queue_count: 2}
        # metadata = %{
        #   oban_name: Oban,
        #   metrics: %{
        #     queues: [%{queue: :default, available: 5, executing: 2, limit: 10, ...}, ...],
        #     total: %{available: 10, executing: 3, ...}
        #   }
        # }
      end, nil)

  ## Standalone Usage

  Query queue metrics directly without configuring the plugin:

      ObanDoctor.Plugins.QueueMetrics.metrics(MyApp.Repo, oban: Oban)
      #=> %{
      #     queues: [
      #       %{queue: :default, available: 5, executing: 2, limit: 10, utilization_pct: 20.0, ...}
      #     ],
      #     total: %{available: 5, executing: 2, ...}
      #   }

      # Filter to specific queues
      ObanDoctor.Plugins.QueueMetrics.metrics(MyApp.Repo, oban: Oban, queues: [:default])

  ## Metrics

  | Metric | Description |
  |--------|-------------|
  | `available` | Jobs ready to execute immediately |
  | `scheduled` | Jobs scheduled for future execution |
  | `executing` | Jobs currently being processed |
  | `retryable` | Failed jobs waiting for retry |
  | `completed` | Successfully completed jobs |
  | `discarded` | Jobs that exceeded max attempts |
  | `cancelled` | Manually cancelled jobs |
  | `limit` | Configured concurrency limit for the queue |
  | `utilization_pct` | Current utilization: `executing / limit * 100` |

  ## Capacity Planning

  Use `utilization_pct` to identify queues that need scaling:

      metrics = ObanDoctor.Plugins.QueueMetrics.metrics(MyApp.Repo, oban: Oban)

      metrics.queues
      |> Enum.filter(& &1.utilization_pct > 80)
      |> Enum.each(fn queue ->
        Logger.warning("Queue \#{queue.queue} at \#{queue.utilization_pct}% utilization")
      end)
  """

  @behaviour Oban.Plugin

  use GenServer

  alias Oban.{Peer, Plugin, Validation}
  alias __MODULE__, as: State

  import Ecto.Query

  require Logger

  @type option ::
          Plugin.option()
          | {:interval, pos_integer()}
          | {:queues, [atom()]}

  defstruct [:conf, :timer, interval: :timer.minutes(5), queues: nil]

  @default_prefix "public"

  @doc false
  @spec child_spec(Keyword.t()) :: Supervisor.child_spec()
  def child_spec(opts), do: super(opts)

  @impl Plugin
  @spec start_link([option()]) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)

    GenServer.start_link(__MODULE__, struct!(State, opts), name: name)
  end

  @impl Plugin
  def validate(opts) do
    Validation.validate_schema(opts,
      conf: :any,
      name: :any,
      interval: :pos_integer,
      queues: {:list, :atom}
    )
  end

  @impl Plugin
  def format_logger_output(_conf, meta) do
    Map.take(meta, [:queue_count])
  end

  @impl GenServer
  def init(state) do
    Process.flag(:trap_exit, true)

    :telemetry.execute([:oban, :plugin, :init], %{}, %{conf: state.conf, plugin: __MODULE__})

    {:ok, schedule_poll(state)}
  end

  @impl GenServer
  def terminate(_reason, %State{timer: timer}) do
    if is_reference(timer), do: Process.cancel_timer(timer)

    :ok
  end

  @impl GenServer
  def handle_info(:poll, %State{conf: conf} = state) do
    meta = %{conf: conf, plugin: __MODULE__}

    :telemetry.span([:oban, :plugin], meta, fn ->
      extra = check_leadership_and_emit(state)
      {:ok, Map.merge(meta, extra)}
    end)

    {:noreply, schedule_poll(state)}
  end

  def handle_info(message, state) do
    Logger.warning(
      message: "Received unexpected message: #{inspect(message)}",
      source: :oban_doctor,
      module: __MODULE__
    )

    {:noreply, state}
  end

  defp schedule_poll(state) do
    %{state | timer: Process.send_after(self(), :poll, state.interval)}
  end

  defp check_leadership_and_emit(%State{conf: conf, queues: queues_filter} = state) do
    if Peer.leader?(conf) do
      metrics = collect_and_emit_telemetry(state)
      %{queue_count: length(metrics.queues), queues_filter: queues_filter}
    else
      %{}
    end
  end

  defp collect_and_emit_telemetry(%State{conf: conf, queues: queues_filter}) do
    metrics = metrics(conf.repo, conf: conf, queues: queues_filter)

    :telemetry.execute(
      [:oban_doctor, :queue, :metrics],
      %{queue_count: length(metrics.queues)},
      %{metrics: metrics, oban_name: conf.name}
    )

    metrics
  end

  @doc """
  Query current queue metrics from the database.

  Returns a map with queue statistics including job counts by state.

  ## Options

    * `:oban` - Oban instance name to get config from (prefix, queues, limits)
    * `:conf` - Oban config struct (when called from a plugin)
    * `:queues` - List of queue names to filter to (default: all from config)

  The prefix, queues, and limits are automatically extracted from the Oban
  configuration via `:oban` or `:conf`.

  ## Return Value

  Returns a map with `:queues` (list of per-queue stats) and `:total` (aggregated counts).

  Per-queue stats include:
    * `:queue` - Queue name as atom
    * `:available`, `:scheduled`, `:executing`, `:retryable`, `:completed`, `:discarded`, `:cancelled` - Job counts by state
    * `:limit` - Configured concurrency limit (when config available)
    * `:utilization_pct` - Current utilization as percentage: `executing / limit * 100` (when limit available)

  ## Examples

      # Use running Oban instance config (prefix, queues, limits)
      iex> QueueMetrics.metrics(MyApp.Repo, oban: Oban)
      %{
        queues: [
          %{queue: :default, available: 5, scheduled: 10, executing: 2, limit: 10, utilization_pct: 20.0, ...},
          %{queue: :mailers, available: 0, scheduled: 3, executing: 1, limit: 5, utilization_pct: 20.0, ...}
        ],
        total: %{available: 5, scheduled: 13, executing: 3, ...}
      }

      # Filter to specific queues
      iex> QueueMetrics.metrics(MyApp.Repo, oban: Oban, queues: [:default])
      %{queues: [%{queue: :default, ...}], total: ...}

  """
  @spec metrics(module(), keyword()) :: map()
  def metrics(repo, opts \\ []) do
    prefix = get_prefix(opts)
    {expected_queues, limits} = resolve_expected_queues(opts)

    queues_to_query =
      if expected_queues do
        MapSet.to_list(expected_queues)
      else
        nil
      end

    results = query_job_counts(repo, prefix, queues_to_query)
    format_results(results, expected_queues, limits)
  end

  defp get_prefix(opts) do
    cond do
      conf = Keyword.get(opts, :conf) ->
        Map.get(conf, :prefix, @default_prefix)

      oban_name = Keyword.get(opts, :oban) ->
        case Oban.config(oban_name) do
          %{prefix: prefix} -> prefix
          _ -> @default_prefix
        end

      true ->
        @default_prefix
    end
  end

  # Returns {expected_queues_set, limits_map}
  defp resolve_expected_queues(opts) do
    # Get limits from Oban config if available
    limits = get_limits_from_config(opts)

    # Get expected queues - either explicit list or from config
    expected_queues =
      case Keyword.get(opts, :queues) do
        nil -> get_queues_from_config(opts)
        queues -> MapSet.new(queues)
      end

    {expected_queues, limits}
  end

  defp get_limits_from_config(opts) do
    cond do
      conf = Keyword.get(opts, :conf) ->
        parse_queue_config(conf.queues)

      oban_name = Keyword.get(opts, :oban) ->
        case Oban.config(oban_name) do
          %{queues: queues} -> parse_queue_config(queues)
          _ -> %{}
        end

      true ->
        %{}
    end
  end

  defp get_queues_from_config(opts) do
    cond do
      conf = Keyword.get(opts, :conf) ->
        conf.queues |> Keyword.keys() |> MapSet.new()

      oban_name = Keyword.get(opts, :oban) ->
        case Oban.config(oban_name) do
          %{queues: queues} -> queues |> Keyword.keys() |> MapSet.new()
          _ -> nil
        end

      true ->
        nil
    end
  end

  # Parse queue config which can be:
  # - [queue: 10] (simple limit)
  # - [queue: [limit: 10, ...]] (keyword list with options)
  defp parse_queue_config(queues) when is_list(queues) do
    Map.new(queues, fn
      {queue, limit} when is_integer(limit) -> {queue, limit}
      {queue, opts} when is_list(opts) -> {queue, Keyword.get(opts, :limit)}
      {queue, _} -> {queue, nil}
    end)
  end

  defp parse_queue_config(_), do: %{}

  defp query_job_counts(repo, prefix, queues_filter) do
    base_query =
      from(j in {"oban_jobs", Oban.Job},
        group_by: [j.queue, j.state],
        select: %{queue: j.queue, state: j.state, count: count(j.id)}
      )

    query =
      if queues_filter do
        queue_strings = Enum.map(queues_filter, &to_string/1)
        from(j in base_query, where: j.queue in ^queue_strings)
      else
        base_query
      end

    query
    |> Ecto.Query.put_query_prefix(prefix)
    |> repo.all()
  end

  defp format_results(results, expected_queues, limits) do
    by_queue =
      results
      |> Enum.group_by(& &1.queue)
      |> Enum.map(fn {queue, rows} ->
        queue_atom = String.to_atom(queue)

        rows
        |> Enum.reduce(%{queue: queue_atom}, fn %{state: state, count: count}, acc ->
          Map.put(acc, String.to_atom(state), count)
        end)
        |> add_missing_states()
        |> add_limit(queue_atom, limits)
        |> add_utilization()
      end)

    # Add empty queues from expected_queues that aren't in results
    by_queue = add_missing_queues(by_queue, expected_queues, limits)

    by_queue = Enum.sort_by(by_queue, & &1.queue)

    totals =
      results
      |> Enum.reduce(%{}, fn %{state: state, count: count}, acc ->
        Map.update(acc, String.to_atom(state), count, &(&1 + count))
      end)
      |> add_missing_states()

    %{queues: by_queue, total: totals}
  end

  defp add_limit(queue_stats, queue_name, limits) do
    case Map.get(limits, queue_name) do
      nil -> queue_stats
      limit -> Map.put(queue_stats, :limit, limit)
    end
  end

  defp add_utilization(%{executing: executing, limit: limit} = queue_stats)
       when is_integer(limit) and limit > 0 do
    utilization = Float.round(executing / limit * 100, 1)
    Map.put(queue_stats, :utilization_pct, utilization)
  end

  defp add_utilization(queue_stats), do: queue_stats

  defp add_missing_queues(by_queue, nil, _limits), do: by_queue

  defp add_missing_queues(by_queue, expected_queues, limits) do
    existing_queues = MapSet.new(by_queue, & &1.queue)

    expected_queues
    |> Enum.reject(&MapSet.member?(existing_queues, &1))
    |> Enum.reduce(by_queue, fn queue, acc ->
      [empty_queue_stats(queue, limits) | acc]
    end)
  end

  defp empty_queue_stats(queue, limits) do
    %{queue: queue}
    |> add_missing_states()
    |> add_limit(queue, limits)
    |> add_utilization()
  end

  @states [:available, :scheduled, :executing, :retryable, :completed, :discarded, :cancelled]

  defp add_missing_states(map) do
    Enum.reduce(@states, map, fn state, acc ->
      Map.put_new(acc, state, 0)
    end)
  end
end
