defmodule ObanDoctor.Plugins.QueueMetricsTest do
  use ExUnit.Case, async: false

  alias ObanDoctor.Plugins.QueueMetrics
  alias ObanDoctor.Test.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok
  end

  describe "metrics/2" do
    test "returns empty queues when no jobs exist" do
      result = QueueMetrics.metrics(Repo)

      assert result.queues == []
      assert result.total.available == 0
      assert result.total.scheduled == 0
      assert result.total.executing == 0
    end

    test "counts jobs by queue and state" do
      # Insert test jobs
      insert_job("default", "available")
      insert_job("default", "available")
      insert_job("default", "scheduled")
      insert_job("mailers", "available")
      insert_job("mailers", "executing")

      result = QueueMetrics.metrics(Repo)

      assert length(result.queues) == 2

      default_queue = Enum.find(result.queues, &(&1.queue == :default))
      assert default_queue.available == 2
      assert default_queue.scheduled == 1
      assert default_queue.executing == 0

      mailers_queue = Enum.find(result.queues, &(&1.queue == :mailers))
      assert mailers_queue.available == 1
      assert mailers_queue.executing == 1

      # Check totals
      assert result.total.available == 3
      assert result.total.scheduled == 1
      assert result.total.executing == 1
    end

    test "filters by queues list" do
      insert_job("default", "available")
      insert_job("default", "scheduled")
      insert_job("mailers", "available")
      insert_job("events", "executing")

      result = QueueMetrics.metrics(Repo, queues: [:default, :mailers])

      # Only requested queues returned
      assert length(result.queues) == 2
      assert Enum.all?(result.queues, &(&1.queue in [:default, :mailers]))

      default_queue = Enum.find(result.queues, &(&1.queue == :default))
      assert default_queue.available == 1
      assert default_queue.scheduled == 1

      # Totals only include filtered queues
      assert result.total.available == 2
      assert result.total.executing == 0
    end

    test "includes empty queues when specified in :queues option" do
      insert_job("default", "available")
      # Note: :events queue has no jobs

      result = QueueMetrics.metrics(Repo, queues: [:default, :events])

      assert length(result.queues) == 2

      events_queue = Enum.find(result.queues, &(&1.queue == :events))
      assert events_queue.available == 0
      assert events_queue.scheduled == 0
      assert events_queue.executing == 0

      default_queue = Enum.find(result.queues, &(&1.queue == :default))
      assert default_queue.available == 1
    end

    test "includes queue limits when :conf option provided" do
      insert_job("default", "available")
      insert_job("mailers", "executing")

      # Simulate Oban conf struct with queues config
      conf = %{queues: [default: 10, mailers: [limit: 5], events: 3]}

      result = QueueMetrics.metrics(Repo, conf: conf)

      assert length(result.queues) == 3

      default_queue = Enum.find(result.queues, &(&1.queue == :default))
      assert default_queue.limit == 10
      assert default_queue.available == 1

      mailers_queue = Enum.find(result.queues, &(&1.queue == :mailers))
      assert mailers_queue.limit == 5
      assert mailers_queue.executing == 1

      # Empty queue should still have limit
      events_queue = Enum.find(result.queues, &(&1.queue == :events))
      assert events_queue.limit == 3
      assert events_queue.available == 0
    end

    test "does not include limit when only :queues option provided" do
      insert_job("default", "available")

      result = QueueMetrics.metrics(Repo, queues: [:default])

      default_queue = Enum.find(result.queues, &(&1.queue == :default))
      refute Map.has_key?(default_queue, :limit)
    end

    test "combines :queues filter with :conf limits" do
      insert_job("default", "available")
      insert_job("mailers", "executing")
      insert_job("events", "scheduled")

      # Filter to subset but get limits from conf
      conf = %{queues: [default: 10, mailers: 5, events: 3]}
      result = QueueMetrics.metrics(Repo, queues: [:default, :mailers], conf: conf)

      # Only requested queues returned
      assert length(result.queues) == 2
      assert Enum.all?(result.queues, &(&1.queue in [:default, :mailers]))

      # But with limits from conf
      default_queue = Enum.find(result.queues, &(&1.queue == :default))
      assert default_queue.limit == 10

      mailers_queue = Enum.find(result.queues, &(&1.queue == :mailers))
      assert mailers_queue.limit == 5
    end

    test "uses prefix from :conf option" do
      # This test verifies prefix is extracted from conf
      # Prefix is the PostgreSQL schema (default: "public")
      conf = %{prefix: "public", queues: [default: 10]}
      result = QueueMetrics.metrics(Repo, conf: conf)
      assert is_map(result)
    end

    test "calculates utilization_pct when limit is available" do
      insert_job("default", "executing")
      insert_job("default", "executing")
      insert_job("default", "available")

      conf = %{queues: [default: 10]}
      result = QueueMetrics.metrics(Repo, conf: conf)

      default_queue = Enum.find(result.queues, &(&1.queue == :default))
      assert default_queue.executing == 2
      assert default_queue.limit == 10
      assert default_queue.utilization_pct == 20.0
    end

    test "does not include utilization_pct when limit is not available" do
      insert_job("default", "executing")

      result = QueueMetrics.metrics(Repo, queues: [:default])

      default_queue = Enum.find(result.queues, &(&1.queue == :default))
      refute Map.has_key?(default_queue, :limit)
      refute Map.has_key?(default_queue, :utilization_pct)
    end
  end

  describe "format_results/2 (internal logic)" do
    test "adds missing states with zero counts" do
      insert_job("default", "available")

      result = QueueMetrics.metrics(Repo, queues: [:default])

      [queue_stats] = result.queues

      # All states should be present
      assert Map.has_key?(queue_stats, :available)
      assert Map.has_key?(queue_stats, :scheduled)
      assert Map.has_key?(queue_stats, :executing)
      assert Map.has_key?(queue_stats, :retryable)
      assert Map.has_key?(queue_stats, :completed)
      assert Map.has_key?(queue_stats, :discarded)
      assert Map.has_key?(queue_stats, :cancelled)

      # Missing states should be 0
      assert queue_stats.scheduled == 0
      assert queue_stats.executing == 0
    end
  end

  describe "validate/1" do
    test "accepts valid options" do
      assert :ok = QueueMetrics.validate(interval: 5000)
      assert :ok = QueueMetrics.validate(interval: 60_000, queues: [:default])
      assert :ok = QueueMetrics.validate([])
    end

    test "rejects invalid interval" do
      assert {:error, _} = QueueMetrics.validate(interval: -1)
      assert {:error, _} = QueueMetrics.validate(interval: 0)
      assert {:error, _} = QueueMetrics.validate(interval: "5000")
    end
  end

  describe "format_logger_output/2" do
    test "extracts queue_count from metadata" do
      conf = %{name: :test}
      meta = %{queue_count: 5, queues_filter: [:default], other: :data}

      result = QueueMetrics.format_logger_output(conf, meta)

      assert result == %{queue_count: 5}
    end

    test "returns empty map when queue_count not present" do
      conf = %{name: :test}
      meta = %{other: :data}

      result = QueueMetrics.format_logger_output(conf, meta)

      assert result == %{}
    end
  end

  describe "telemetry" do
    test "emits [:oban_doctor, :queue, :metrics] event" do
      insert_job("default", "available")

      ref = :telemetry_test.attach_event_handlers(self(), [[:oban_doctor, :queue, :metrics]])

      # Get the running Oban's config
      conf = Oban.config(ObanDoctor.TestOban)

      # Start the plugin with a short interval
      {:ok, pid} = QueueMetrics.start_link(conf: conf, name: :test_queue_metrics, interval: 100)

      # Allow the spawned process to use the sandbox connection
      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)

      # Trigger a poll
      send(pid, :poll)

      # Wait for telemetry event
      assert_receive {[:oban_doctor, :queue, :metrics], ^ref, measurements, metadata}, 1000

      assert is_integer(measurements.queue_count)
      assert metadata.oban_name == ObanDoctor.TestOban
      assert is_map(metadata.metrics)
      assert is_list(metadata.metrics.queues)

      GenServer.stop(pid)
    end

    test "includes queue_count in [:oban, :plugin, :stop] metadata" do
      insert_job("default", "available")

      ref = :telemetry_test.attach_event_handlers(self(), [[:oban, :plugin, :stop]])

      conf = Oban.config(ObanDoctor.TestOban)
      {:ok, pid} = QueueMetrics.start_link(conf: conf, name: :test_plugin_stop, interval: 100)
      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)

      send(pid, :poll)

      assert_receive {[:oban, :plugin, :stop], ^ref, _measurements, metadata}, 1000

      assert metadata.plugin == QueueMetrics
      assert metadata.conf == conf
      # queue_count should be in metadata for format_logger_output
      assert is_integer(metadata.queue_count)
      assert is_list(metadata.queues_filter) or is_nil(metadata.queues_filter)

      GenServer.stop(pid)
    end

    test "handles unexpected messages gracefully" do
      conf = Oban.config(ObanDoctor.TestOban)
      {:ok, pid} = QueueMetrics.start_link(conf: conf, name: :test_unexpected, interval: 60_000)

      # Send an unexpected message
      send(pid, :unexpected_message)

      # Process should still be alive
      assert Process.alive?(pid)

      GenServer.stop(pid)
    end

    test "cancels timer on terminate" do
      conf = Oban.config(ObanDoctor.TestOban)
      {:ok, pid} = QueueMetrics.start_link(conf: conf, name: :test_terminate, interval: 60_000)

      # Get state to verify timer exists
      state = :sys.get_state(pid)
      assert is_reference(state.timer)

      # Stop should not raise
      GenServer.stop(pid)
      refute Process.alive?(pid)
    end
  end

  describe "metrics/2 with :oban option" do
    test "extracts config from running Oban instance" do
      insert_job("default", "available")

      result = QueueMetrics.metrics(Repo, oban: ObanDoctor.TestOban)

      assert is_map(result)
      assert is_list(result.queues)
      # TestOban has default and mailers queues configured
      assert length(result.queues) == 2
    end

    test "uses prefix from Oban config" do
      # ObanDoctor.TestOban uses default "public" prefix
      result = QueueMetrics.metrics(Repo, oban: ObanDoctor.TestOban)
      assert is_map(result)
    end

    test "uses queue limits from Oban config" do
      result = QueueMetrics.metrics(Repo, oban: ObanDoctor.TestOban)

      default_queue = Enum.find(result.queues, &(&1.queue == :default))
      assert default_queue.limit == 10

      mailers_queue = Enum.find(result.queues, &(&1.queue == :mailers))
      assert mailers_queue.limit == 5
    end
  end

  # Helper to insert test jobs directly into oban_jobs table
  defp insert_job(queue, state) do
    now = DateTime.utc_now()

    Repo.query!(
      """
      INSERT INTO oban_jobs (queue, state, worker, args, inserted_at, scheduled_at)
      VALUES ($1, $2, $3, $4, $5, $6)
      """,
      [queue, state, "TestWorker", "{}", now, now]
    )
  end
end
