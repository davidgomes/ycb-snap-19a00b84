# Runtime Plugins

ObanDoctor provides runtime plugins for monitoring Oban queue health and capacity.

## Available Plugins

| Plugin | Description |
|--------|-------------|
| [QueueMetrics](ObanDoctor.Plugins.QueueMetrics.html) | Live queue metrics including job counts and utilization |
| [TableHealth](ObanDoctor.Plugins.TableHealth.html) | Table size, bloat, and vacuum monitoring with alerts |
| [IndexHealth](ObanDoctor.Plugins.IndexHealth.html) | Index size, usage, and health monitoring with alerts |

## Configuration

Add plugins to your Oban configuration:

```elixir
config :my_app, Oban,
  repo: MyApp.Repo,
  queues: [default: 10, mailers: 5],
  plugins: [
    {ObanDoctor.Plugins.QueueMetrics, interval: :timer.minutes(5)}
  ]
```

Plugins automatically use your Oban instance's configuration (repo, prefix, queues, limits). Only the leader node emits telemetry, ensuring metrics are recorded once across your cluster.

## Multiple Oban Instances

Each Oban instance runs its own plugin:

```elixir
config :my_app, Oban,
  plugins: [{ObanDoctor.Plugins.QueueMetrics, interval: :timer.minutes(5)}]

config :my_app, MyApp.SecondaryOban,
  plugins: [{ObanDoctor.Plugins.QueueMetrics, interval: :timer.minutes(5)}]
```

## On-Demand Queries

Query metrics directly without configuring the plugin:

```elixir
ObanDoctor.Plugins.QueueMetrics.metrics(MyApp.Repo, oban: Oban)

# Or for a secondary instance
ObanDoctor.Plugins.QueueMetrics.metrics(MyApp.Repo, oban: MyApp.SecondaryOban)
```

This is useful for debugging, dashboards, or one-off capacity checks.

## Telemetry Events

All plugins emit telemetry events that can be consumed by APM tools like NewRelic, Datadog, or custom handlers.

### QueueMetrics

Emits `[:oban_doctor, :queue, :metrics]` on each scheduled poll:

| Key | Type | Description |
|-----|------|-------------|
| `measurements.queue_count` | integer | Number of queues reported |
| `metadata.oban_name` | atom | Oban instance name |
| `metadata.metrics.queues` | list | Per-queue statistics |
| `metadata.metrics.total` | map | Aggregated totals |

Per-queue statistics include: `queue`, `available`, `scheduled`, `executing`, `retryable`, `completed`, `discarded`, `cancelled`, `limit`, `utilization_pct`.

### TableHealth

Emits `[:oban_doctor, :table, :health]` on each scheduled poll:

| Key | Type | Description |
|-----|------|-------------|
| `measurements.table_size_mb` | integer | Table size in megabytes |
| `measurements.dead_tuple_ratio` | float | Ratio of dead to total tuples |
| `measurements.alert_count` | integer | Number of threshold violations |
| `metadata.oban_name` | atom | Oban instance name |
| `metadata.metrics` | map | Full metrics including sizes, vacuum stats, job counts |
| `metadata.alerts` | list | List of `{alert_type, message}` tuples |

Metrics include: `table_size_bytes`, `table_size_mb`, `index_size_bytes`, `total_size_bytes`, `live_tuples`, `dead_tuples`, `dead_tuple_ratio`, `last_vacuum`, `last_autovacuum`, `hours_since_vacuum`, `hours_since_autovacuum`, `jobs_by_state`, `total_jobs`, `alerts`.

### IndexHealth

Emits `[:oban_doctor, :index, :health]` on each scheduled poll:

| Key | Type | Description |
|-----|------|-------------|
| `measurements.index_count` | integer | Number of indexes on the oban_jobs table |
| `measurements.unused_count` | integer | Number of indexes with zero scans |
| `measurements.orphaned_count` | integer | Number of orphaned indexes from failed REINDEX |
| `measurements.alert_count` | integer | Number of actionable issues |
| `metadata.oban_name` | atom | Oban instance name |
| `metadata.metrics` | map | Full metrics including indexes list, sizes, and ratios |
| `metadata.alerts` | list | List of `{alert_type, message}` tuples |

Per-index metrics include: `index_name`, `index_size_bytes`, `index_scans`, `tuples_read`, `tuples_fetched`, `is_unused`, `is_orphaned_reindex`, `size_ratio`.

#### IndexHealth Alerts

| Alert Type | Description |
|------------|-------------|
| `:orphaned_reindex` | Index with `_ccnew` suffix from failed `REINDEX CONCURRENTLY` |
| `:unused_index` | Index with zero scans since statistics reset |

#### IndexHealth Configuration

```elixir
config :my_app, Oban,
  plugins: [
    {ObanDoctor.Plugins.IndexHealth, interval: :timer.hours(6)}
  ]
```

See the module documentation for guidance on fixing common index health issues.

#### TableHealth Configuration

```elixir
config :my_app, Oban,
  plugins: [
    {ObanDoctor.Plugins.TableHealth, interval: :timer.hours(6)}
  ]
```

#### TableHealth Default Thresholds

| Threshold | Default | Description |
|-----------|---------|-------------|
| `table_size_mb` | 1000 | Alert when table exceeds this size in MB |
| `dead_tuple_ratio` | 0.1 | Alert when dead tuple ratio exceeds 10% |
| `min_tuples_for_ratio_alert` | 1000 | Minimum tuples before ratio alert fires |
| `hours_since_vacuum` | 24 | Alert when no vacuum in this many hours |

Override only the thresholds you need:

```elixir
config :my_app, Oban,
  plugins: [
    {ObanDoctor.Plugins.TableHealth,
     interval: :timer.hours(6),
     thresholds: [
       table_size_mb: 2000  # Override to 2GB, other thresholds use defaults
     ]}
  ]
```

## NewRelic Integration

NewRelic's Elixir agent automatically captures telemetry events. To query ObanDoctor metrics in NewRelic:

### NRQL Queries

```sql
-- Queue utilization over time
SELECT average(queue_metrics.utilization_pct)
FROM ObanDoctorQueueMetrics
FACET queue
TIMESERIES

-- Available jobs by queue
SELECT sum(queue_metrics.available)
FROM ObanDoctorQueueMetrics
FACET queue
TIMESERIES

-- Queues with high utilization (>80%)
SELECT * FROM ObanDoctorQueueMetrics
WHERE queue_metrics.utilization_pct > 80

-- Total executing jobs across all queues
SELECT sum(total.executing)
FROM ObanDoctorQueueMetrics
TIMESERIES
```

### Custom Telemetry Handler

If your APM doesn't auto-capture telemetry, attach a custom handler:

```elixir
# In your application startup
:telemetry.attach(
  "oban-doctor-metrics",
  [:oban_doctor, :queue, :metrics],
  &MyApp.Telemetry.handle_queue_metrics/4,
  nil
)

# Handler module
defmodule MyApp.Telemetry do
  def handle_queue_metrics(_event, measurements, metadata, _config) do
    # Send to your monitoring system
    for queue_stats <- metadata.metrics.queues do
      MyApp.Metrics.gauge("oban.queue.available", queue_stats.available,
        tags: [queue: queue_stats.queue]
      )
      MyApp.Metrics.gauge("oban.queue.executing", queue_stats.executing,
        tags: [queue: queue_stats.queue]
      )
      if queue_stats[:utilization_pct] do
        MyApp.Metrics.gauge("oban.queue.utilization", queue_stats.utilization_pct,
          tags: [queue: queue_stats.queue]
        )
      end
    end
  end
end
```

See each plugin's module documentation for detailed options.
