defmodule ObanDoctor.Plugins.TableHealth do
  @moduledoc """
  Monitors the health of the oban_jobs table including size, bloat, and vacuum status.

  ## As Oban Plugin

  Add to your Oban config for scheduled telemetry emission:

      config :my_app, Oban,
        plugins: [
          {ObanDoctor.Plugins.TableHealth, interval: :timer.hours(6)}
        ]

  The plugin automatically uses your Oban instance's configuration (repo, prefix).
  Only the leader node (via `Oban.Peer`) executes the scheduled check, ensuring
  metrics are emitted once across your cluster.

  ### Plugin Options

    * `:interval` - How often to emit telemetry in ms (default: 6 hours)
    * `:thresholds` - Alert thresholds (see below)

  ### Default Thresholds

    * `:table_size_mb` - Alert when table exceeds this size (default: 1000 MB)
    * `:dead_tuple_ratio` - Alert when dead tuple ratio exceeds this (default: 0.1 = 10%)
    * `:min_tuples_for_ratio_alert` - Minimum total tuples before dead tuple ratio alert fires (default: 1000)
    * `:hours_since_vacuum` - Alert when hours since last vacuum exceeds this (default: 24)

  Override any threshold while keeping defaults for the rest:

      config :my_app, Oban,
        plugins: [
          {ObanDoctor.Plugins.TableHealth,
           interval: :timer.hours(6),
           thresholds: [
             table_size_mb: 2000,       # Override to 2GB
             hours_since_vacuum: 48     # Override to 48 hours
             # dead_tuple_ratio and min_tuples_for_ratio_alert use defaults
           ]}
        ]

  ### Telemetry

  Emits `[:oban_doctor, :table, :health]` with health metrics:

      :telemetry.attach("my-handler", [:oban_doctor, :table, :health], fn _event, measurements, metadata, _config ->
        # measurements = %{table_size_mb: 150, dead_tuple_ratio: 0.05, alert_count: 0}
        # metadata = %{
        #   oban_name: Oban,
        #   metrics: %{table_size_bytes: ..., dead_tuples: ..., ...},
        #   alerts: []
        # }
      end, nil)

  ## Standalone Usage

  Query table health metrics directly without configuring the plugin:

      ObanDoctor.Plugins.TableHealth.metrics(MyApp.Repo)
      #=> %{
      #     table_size_bytes: 157286400,
      #     table_size_mb: 150,
      #     index_size_bytes: 52428800,
      #     total_size_bytes: 209715200,
      #     live_tuples: 500000,
      #     dead_tuples: 25000,
      #     dead_tuple_ratio: 0.05,
      #     last_vacuum: ~U[2024-01-15 10:30:00Z],
      #     last_autovacuum: ~U[2024-01-15 12:45:00Z],
      #     hours_since_vacuum: 2.5,
      #     hours_since_autovacuum: 0.25,
      #     jobs_by_state: %{available: 100, completed: 400000, ...},
      #     total_jobs: 500100,
      #     alerts: []
      #   }

  ## Metrics

  | Metric | Description |
  |--------|-------------|
  | `table_size_bytes` | Size of the oban_jobs table in bytes |
  | `table_size_mb` | Size of the oban_jobs table in megabytes |
  | `index_size_bytes` | Size of all indexes on oban_jobs in bytes |
  | `total_size_bytes` | Total size including table and indexes |
  | `live_tuples` | Number of live (visible) rows |
  | `dead_tuples` | Number of dead (deleted but not vacuumed) rows |
  | `dead_tuple_ratio` | Ratio of dead to total tuples (dead / (live + dead)) |
  | `last_vacuum` | Timestamp of last manual VACUUM |
  | `last_autovacuum` | Timestamp of last autovacuum |
  | `hours_since_vacuum` | Hours since last manual VACUUM (nil if never) |
  | `hours_since_autovacuum` | Hours since last autovacuum (nil if never) |
  | `jobs_by_state` | Count of jobs grouped by state |
  | `total_jobs` | Total number of jobs in the table |
  | `alerts` | List of `{alert_type, message}` tuples for threshold violations |

  ## Bloat Estimation

  The `dead_tuple_ratio` serves as a proxy for table bloat. PostgreSQL's autovacuum
  removes dead tuples but doesn't reclaim disk space (that requires VACUUM FULL).
  A high dead tuple ratio (>10%) indicates the table may benefit from maintenance.

  For accurate bloat measurement, consider using the `pgstattuple` extension directly.
  """

  @behaviour Oban.Plugin

  use GenServer

  alias Oban.{Peer, Plugin, Validation}
  alias __MODULE__, as: State

  require Logger

  @type option ::
          Plugin.option()
          | {:interval, pos_integer()}
          | {:thresholds, keyword()}

  defstruct [:conf, :timer, interval: :timer.hours(6), thresholds: []]

  @default_prefix "public"

  @default_thresholds [
    table_size_mb: 1000,
    dead_tuple_ratio: 0.1,
    min_tuples_for_ratio_alert: 1000,
    hours_since_vacuum: 24
  ]

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
      thresholds: :keyword
    )
  end

  @impl Plugin
  def format_logger_output(_conf, meta) do
    Map.take(meta, [:table_size_mb, :alert_count])
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

  defp check_leadership_and_emit(%State{conf: conf, thresholds: thresholds} = state) do
    if Peer.leader?(conf) do
      metrics = collect_and_emit_telemetry(state)
      merged_thresholds = Keyword.merge(@default_thresholds, thresholds)
      alerts = generate_alerts(metrics, merged_thresholds)
      %{table_size_mb: metrics.table_size_mb, alert_count: length(alerts)}
    else
      %{}
    end
  end

  defp collect_and_emit_telemetry(%State{conf: conf, thresholds: thresholds}) do
    merged_thresholds = Keyword.merge(@default_thresholds, thresholds)
    metrics = metrics(conf.repo, conf: conf, thresholds: merged_thresholds)
    alerts = generate_alerts(metrics, merged_thresholds)

    :telemetry.execute(
      [:oban_doctor, :table, :health],
      %{
        table_size_mb: metrics.table_size_mb,
        dead_tuple_ratio: metrics.dead_tuple_ratio,
        alert_count: length(alerts)
      },
      %{metrics: metrics, alerts: alerts, oban_name: conf.name}
    )

    metrics
  end

  @doc """
  Query current table health metrics from the database.

  Returns a map with table statistics including size, vacuum status, and job counts.

  ## Options

    * `:oban` - Oban instance name to get config from (prefix, queues)
    * `:conf` - Oban config struct (when called from a plugin)
    * `:thresholds` - Threshold values for generating alerts

  The prefix is automatically extracted from the Oban configuration via `:oban` or `:conf`.

  ## Return Value

  Returns a map with table health metrics. See module documentation for full list.

  ## Examples

      # Use running Oban instance config
      iex> TableHealth.metrics(MyApp.Repo, oban: Oban)
      %{
        table_size_bytes: 157286400,
        table_size_mb: 150,
        ...
      }

  """
  @spec metrics(module(), keyword()) :: map()
  def metrics(repo, opts \\ []) do
    prefix = get_prefix(opts)
    thresholds = Keyword.get(opts, :thresholds, @default_thresholds)

    # Query table/index sizes
    size_metrics = query_table_sizes(repo, prefix)

    # Query vacuum stats
    vacuum_metrics = query_vacuum_stats(repo, prefix)

    # Query jobs by state
    {jobs_by_state, total_jobs} = query_jobs_by_state(repo, prefix)

    # Calculate derived metrics
    dead_tuple_ratio = calculate_dead_tuple_ratio(vacuum_metrics)
    hours_since_vacuum = calculate_hours_since(vacuum_metrics.last_vacuum)
    hours_since_autovacuum = calculate_hours_since(vacuum_metrics.last_autovacuum)

    metrics =
      size_metrics
      |> Map.merge(vacuum_metrics)
      |> Map.merge(%{
        dead_tuple_ratio: dead_tuple_ratio,
        hours_since_vacuum: hours_since_vacuum,
        hours_since_autovacuum: hours_since_autovacuum,
        jobs_by_state: jobs_by_state,
        total_jobs: total_jobs
      })

    alerts = generate_alerts(metrics, thresholds)
    Map.put(metrics, :alerts, alerts)
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

  defp query_table_sizes(repo, prefix) do
    query = """
    SELECT
      pg_table_size(c.oid) as table_size,
      pg_indexes_size(c.oid) as index_size,
      pg_total_relation_size(c.oid) as total_size
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relname = 'oban_jobs' AND n.nspname = $1
    """

    case repo.query(query, [prefix]) do
      {:ok, %{rows: [[table_size, index_size, total_size]]}} ->
        %{
          table_size_bytes: table_size || 0,
          table_size_mb: div(table_size || 0, 1_048_576),
          index_size_bytes: index_size || 0,
          total_size_bytes: total_size || 0
        }

      _ ->
        %{
          table_size_bytes: 0,
          table_size_mb: 0,
          index_size_bytes: 0,
          total_size_bytes: 0
        }
    end
  end

  defp query_vacuum_stats(repo, prefix) do
    query = """
    SELECT
      n_live_tup,
      n_dead_tup,
      last_vacuum,
      last_autovacuum
    FROM pg_stat_user_tables
    WHERE schemaname = $1 AND relname = 'oban_jobs'
    """

    case repo.query(query, [prefix]) do
      {:ok, %{rows: [[live_tup, dead_tup, last_vacuum, last_autovacuum]]}} ->
        %{
          live_tuples: live_tup || 0,
          dead_tuples: dead_tup || 0,
          last_vacuum: parse_timestamp(last_vacuum),
          last_autovacuum: parse_timestamp(last_autovacuum)
        }

      _ ->
        %{
          live_tuples: 0,
          dead_tuples: 0,
          last_vacuum: nil,
          last_autovacuum: nil
        }
    end
  end

  defp parse_timestamp(nil), do: nil

  defp parse_timestamp(%NaiveDateTime{} = naive) do
    DateTime.from_naive!(naive, "Etc/UTC")
  end

  defp parse_timestamp(%DateTime{} = dt), do: dt

  defp parse_timestamp(_), do: nil

  defp query_jobs_by_state(repo, prefix) do
    import Ecto.Query

    query =
      from(j in {"oban_jobs", Oban.Job},
        group_by: j.state,
        select: {j.state, count(j.id)}
      )
      |> Ecto.Query.put_query_prefix(prefix)

    results = repo.all(query)

    jobs_by_state =
      Map.new(results, fn {state, count} ->
        {String.to_atom(state), count}
      end)

    total_jobs = Enum.sum(Enum.map(results, fn {_state, count} -> count end))

    {jobs_by_state, total_jobs}
  end

  defp calculate_dead_tuple_ratio(%{live_tuples: live, dead_tuples: dead}) do
    total = live + dead

    if total > 0 do
      Float.round(dead / total, 4)
    else
      0.0
    end
  end

  defp calculate_hours_since(nil), do: nil

  defp calculate_hours_since(timestamp) do
    diff_seconds = DateTime.diff(DateTime.utc_now(), timestamp, :second)
    Float.round(diff_seconds / 3600, 2)
  end

  defp generate_alerts(metrics, thresholds) do
    []
    |> check_table_size_alert(metrics, thresholds)
    |> check_dead_tuple_alert(metrics, thresholds)
    |> check_vacuum_alert(metrics, thresholds)
  end

  defp check_table_size_alert(alerts, metrics, thresholds) do
    threshold = Keyword.get(thresholds, :table_size_mb, 1000)

    if metrics.table_size_mb > threshold do
      [
        {:table_size,
         "Table size (#{metrics.table_size_mb} MB) exceeds threshold (#{threshold} MB)"}
        | alerts
      ]
    else
      alerts
    end
  end

  defp check_dead_tuple_alert(alerts, metrics, thresholds) do
    threshold = Keyword.get(thresholds, :dead_tuple_ratio, 0.1)
    min_tuples = Keyword.get(thresholds, :min_tuples_for_ratio_alert, 1000)
    total_tuples = metrics.live_tuples + metrics.dead_tuples

    if total_tuples >= min_tuples and metrics.dead_tuple_ratio > threshold do
      ratio_pct = Float.round(metrics.dead_tuple_ratio * 100, 1)
      threshold_pct = Float.round(threshold * 100, 1)

      [
        {:dead_tuple_ratio,
         "Dead tuple ratio (#{ratio_pct}%) exceeds threshold (#{threshold_pct}%)"}
        | alerts
      ]
    else
      alerts
    end
  end

  defp check_vacuum_alert(alerts, metrics, thresholds) do
    threshold = Keyword.get(thresholds, :hours_since_vacuum, 24)

    # Check the most recent vacuum (either manual or auto)
    hours =
      case {metrics.hours_since_vacuum, metrics.hours_since_autovacuum} do
        {nil, nil} -> nil
        {nil, auto} -> auto
        {manual, nil} -> manual
        {manual, auto} -> min(manual, auto)
      end

    cond do
      is_nil(hours) ->
        [{:no_vacuum, "No vacuum has ever been run on the jobs table"} | alerts]

      hours > threshold ->
        [
          {:vacuum_overdue,
           "Last vacuum was #{Float.round(hours, 1)} hours ago (threshold: #{threshold} hours)"}
          | alerts
        ]

      true ->
        alerts
    end
  end
end
