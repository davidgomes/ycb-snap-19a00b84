defmodule ObanDoctor.Plugins.IndexHealth do
  @moduledoc """
  Monitors the health of indexes on the oban_jobs table including size, usage, and bloat.

  ## As Oban Plugin

  Add to your Oban config for scheduled telemetry emission:

      config :my_app, Oban,
        plugins: [
          {ObanDoctor.Plugins.IndexHealth, interval: :timer.hours(6)}
        ]

  The plugin automatically uses your Oban instance's configuration (repo, prefix).
  Only the leader node (via `Oban.Peer`) executes the scheduled check, ensuring
  metrics are emitted once across your cluster.

  ### Plugin Options

    * `:interval` - How often to emit telemetry in ms (default: 6 hours)

  ### Telemetry

  Emits `[:oban_doctor, :index, :health]` with index health metrics:

      :telemetry.attach("my-handler", [:oban_doctor, :index, :health], fn _event, measurements, metadata, _config ->
        # measurements = %{index_count: 5, unused_count: 1, orphaned_count: 0, alert_count: 1}
        # metadata = %{
        #   oban_name: Oban,
        #   metrics: %{indexes: [...], table_size_bytes: ..., ...},
        #   alerts: [{:unused_index, "..."}, {:orphaned_reindex, "..."}]
        # }
      end, nil)

  ## Standalone Usage

  Query index health metrics directly without configuring the plugin:

      ObanDoctor.Plugins.IndexHealth.metrics(MyApp.Repo)
      #=> %{
      #     indexes: [
      #       %{
      #         index_name: "oban_jobs_pkey",
      #         index_size_bytes: 12345678,
      #         index_scans: 1234567,
      #         tuples_read: 2345678,
      #         tuples_fetched: 1234567,
      #         is_unused: false,
      #         is_orphaned_reindex: false,
      #         size_ratio: 0.15
      #       },
      #       ...
      #     ],
      #     table_size_bytes: 82345678,
      #     total_index_size_bytes: 24567890,
      #     index_to_table_ratio: 0.30,
      #     alerts: []
      #   }

  ## Metrics

  | Metric | Description |
  |--------|-------------|
  | `index_name` | Name of the index |
  | `index_size_bytes` | Size of the index in bytes |
  | `index_scans` | Number of index scans performed |
  | `tuples_read` | Number of tuples read via index scans |
  | `tuples_fetched` | Number of tuples fetched via index scans |
  | `is_unused` | True if index has zero scans since stats reset |
  | `is_orphaned_reindex` | True if index appears to be from a failed REINDEX CONCURRENTLY |
  | `size_ratio` | Ratio of this index's size to table size |

  ## Alerts

  The plugin generates alerts for actionable issues:

  | Alert Type | Description |
  |------------|-------------|
  | `:orphaned_reindex` | Index with `_ccnew` suffix from failed `REINDEX CONCURRENTLY` - safe to drop |
  | `:unused_index` | Index with zero scans - review and potentially drop |

  ## Fixing Common Issues

  ### Orphaned Reindex Indexes (`_ccnew` suffix)

  When `REINDEX CONCURRENTLY` fails or is interrupted, it leaves behind indexes with
  `_ccnew` or `_ccnew1` suffixes. These are safe to drop:

      -- Check what it looks like first
      SELECT indexname, indexdef FROM pg_indexes
      WHERE tablename = 'oban_jobs' AND indexname LIKE '%_ccnew%';

      -- Drop the orphaned index
      DROP INDEX CONCURRENTLY oban_jobs_args_index_ccnew1;

  ### Unused Indexes

  Before dropping an unused index, consider:

  1. **Statistics may have been reset** - Check `pg_stat_user_indexes.last_idx_scan`
  2. **Seasonal usage** - Some indexes are only used during reports or backfills
  3. **Recently created** - New indexes won't have scan history

  If you're confident the index is unused:

      DROP INDEX CONCURRENTLY oban_jobs_some_unused_index;

  ### Index Bloat

  High `index_to_table_ratio` (e.g., indexes larger than the table) often indicates bloat.
  Use Oban Pro's [Reindexer plugin](https://hexdocs.pm/oban/Oban.Plugins.Reindexer.html)
  for automatic maintenance:

      config :my_app, Oban,
        plugins: [
          {Oban.Plugins.Reindexer,
           schedule: "@weekly",
           indexes: [
             "oban_jobs_pkey",
             "oban_jobs_state_queue_priority_scheduled_at_id_index"
           ]}
        ]

  Or manually reindex specific indexes:

      REINDEX INDEX CONCURRENTLY oban_jobs_args_index;

  ### Duplicate Indexes

  If you see multiple indexes with similar names (e.g., `oban_jobs_args_index` and
  `oban_jobs_args_index_ccnew`), verify they have the same definition:

      SELECT indexname, indexdef FROM pg_indexes
      WHERE tablename = 'oban_jobs' AND indexname LIKE '%args%';

  If identical, keep the one with more scans and drop the other.

  ### GIN Index Bloat (meta_index, args_index)

  GIN indexes on JSONB columns (`oban_jobs_meta_index`, `oban_jobs_args_index`) can grow
  very large. Options:

  1. **Regular reindexing** via `Oban.Plugins.Reindexer`
  2. **Consider if you need them** - These are optional Oban Pro indexes for workflow
     and uniqueness queries. If you don't use those features heavily, you may not need them.

  ## Limitations

  Index bloat estimation requires the `pgstattuple` extension which needs superuser
  privileges. This plugin focuses on metrics available from standard system catalogs.
  For accurate bloat measurement, use `pgstattuple` directly:

      SELECT * FROM pgstattuple('oban_jobs_pkey');
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

  defstruct [:conf, :timer, interval: :timer.hours(6)]

  @default_prefix "public"

  # Pattern for orphaned indexes from failed REINDEX CONCURRENTLY
  @orphaned_reindex_pattern ~r/_ccnew\d*$/

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
      interval: :pos_integer
    )
  end

  @impl Plugin
  def format_logger_output(_conf, meta) do
    Map.take(meta, [:index_count, :orphaned_count, :alert_count])
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

  defp check_leadership_and_emit(%State{conf: conf} = state) do
    if Peer.leader?(conf) do
      metrics = collect_and_emit_telemetry(state)
      alerts = generate_alerts(metrics)
      unused_count = Enum.count(metrics.indexes, & &1.is_unused)
      orphaned_count = Enum.count(metrics.indexes, & &1.is_orphaned_reindex)

      %{
        index_count: length(metrics.indexes),
        unused_count: unused_count,
        orphaned_count: orphaned_count,
        alert_count: length(alerts)
      }
    else
      %{}
    end
  end

  defp collect_and_emit_telemetry(%State{conf: conf}) do
    metrics = metrics(conf.repo, conf: conf)
    alerts = generate_alerts(metrics)
    unused_count = Enum.count(metrics.indexes, & &1.is_unused)
    orphaned_count = Enum.count(metrics.indexes, & &1.is_orphaned_reindex)

    :telemetry.execute(
      [:oban_doctor, :index, :health],
      %{
        index_count: length(metrics.indexes),
        unused_count: unused_count,
        orphaned_count: orphaned_count,
        alert_count: length(alerts)
      },
      %{metrics: metrics, alerts: alerts, oban_name: conf.name}
    )

    metrics
  end

  @doc """
  Query current index health metrics from the database.

  Returns a map with index statistics for all indexes on the oban_jobs table.

  ## Options

    * `:oban` - Oban instance name to get config from (prefix)
    * `:conf` - Oban config struct (when called from a plugin)

  The prefix is automatically extracted from the Oban configuration via `:oban` or `:conf`.

  ## Return Value

  Returns a map with index health metrics. See module documentation for full list.

  ## Examples

      # Use running Oban instance config
      iex> IndexHealth.metrics(MyApp.Repo, oban: Oban)
      %{
        indexes: [
          %{index_name: "oban_jobs_pkey", index_size_bytes: 12345678, ...},
          ...
        ],
        table_size_bytes: 82345678,
        total_index_size_bytes: 24567890,
        index_to_table_ratio: 0.30,
        alerts: []
      }

  """
  @spec metrics(module(), keyword()) :: map()
  def metrics(repo, opts \\ []) do
    prefix = get_prefix(opts)

    # Query index statistics
    {indexes, table_size_bytes} = query_index_stats(repo, prefix)

    # Calculate total index size
    total_index_size_bytes =
      Enum.reduce(indexes, 0, fn idx, acc -> acc + idx.index_size_bytes end)

    # Calculate index to table ratio
    index_to_table_ratio =
      if table_size_bytes > 0 do
        Float.round(total_index_size_bytes / table_size_bytes, 4)
      else
        0.0
      end

    metrics = %{
      indexes: indexes,
      table_size_bytes: table_size_bytes,
      total_index_size_bytes: total_index_size_bytes,
      index_to_table_ratio: index_to_table_ratio
    }

    alerts = generate_alerts(metrics)
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

  defp query_index_stats(repo, prefix) do
    query = """
    SELECT
      i.indexrelname as index_name,
      pg_relation_size(i.indexrelid) as index_size_bytes,
      i.idx_scan as index_scans,
      i.idx_tup_read as tuples_read,
      i.idx_tup_fetch as tuples_fetched,
      pg_relation_size(i.relid) as table_size_bytes
    FROM pg_stat_user_indexes i
    JOIN pg_class c ON c.oid = i.relid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relname = 'oban_jobs' AND n.nspname = $1
    ORDER BY pg_relation_size(i.indexrelid) DESC
    """

    case repo.query(query, [prefix]) do
      {:ok, %{rows: rows}} when rows != [] ->
        # Get table size from first row (same for all indexes)
        table_size_bytes = rows |> List.first() |> Enum.at(5) || 0

        indexes =
          Enum.map(rows, fn [name, size, scans, read, fetched, _table_size] ->
            size_ratio =
              if table_size_bytes > 0 do
                Float.round((size || 0) / table_size_bytes, 4)
              else
                0.0
              end

            %{
              index_name: name,
              index_size_bytes: size || 0,
              index_scans: scans || 0,
              tuples_read: read || 0,
              tuples_fetched: fetched || 0,
              is_unused: (scans || 0) == 0,
              is_orphaned_reindex: Regex.match?(@orphaned_reindex_pattern, name),
              size_ratio: size_ratio
            }
          end)

        {indexes, table_size_bytes}

      _ ->
        {[], 0}
    end
  end

  defp generate_alerts(metrics) do
    []
    |> check_orphaned_reindex_alerts(metrics)
    |> check_unused_alerts(metrics)
  end

  defp check_orphaned_reindex_alerts(alerts, metrics) do
    # Detect orphaned indexes from failed REINDEX CONCURRENTLY operations
    # These have _ccnew or _ccnew1, _ccnew2 suffixes and are safe to drop
    metrics.indexes
    |> Enum.filter(fn idx -> idx.is_orphaned_reindex end)
    |> Enum.reduce(alerts, fn idx, acc ->
      size_mb = Float.round(idx.index_size_bytes / 1_048_576, 1)

      [
        {:orphaned_reindex,
         "Index #{idx.index_name} (#{size_mb} MB) appears to be orphaned from a failed REINDEX CONCURRENTLY - safe to drop"}
        | acc
      ]
    end)
  end

  defp check_unused_alerts(alerts, metrics) do
    # Alert on unused indexes, excluding orphaned ones (they get their own alert)
    # Note: We can't easily check table age from standard catalogs without tracking
    # creation time, so we alert on all unused indexes but document the caveat
    metrics.indexes
    |> Enum.filter(fn idx -> idx.is_unused and not idx.is_orphaned_reindex end)
    |> Enum.reduce(alerts, fn idx, acc ->
      size_mb = Float.round(idx.index_size_bytes / 1_048_576, 1)

      [
        {:unused_index,
         "Index #{idx.index_name} (#{size_mb} MB) has zero scans since statistics reset"}
        | acc
      ]
    end)
  end
end
