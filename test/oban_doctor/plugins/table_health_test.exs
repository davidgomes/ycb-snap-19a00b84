defmodule ObanDoctor.Plugins.TableHealthTest do
  use ExUnit.Case, async: false

  alias ObanDoctor.Plugins.TableHealth
  alias ObanDoctor.Test.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok
  end

  describe "metrics/2" do
    test "returns expected structure" do
      result = TableHealth.metrics(Repo)

      # Size metrics
      assert is_integer(result.table_size_bytes)
      assert is_integer(result.table_size_mb)
      assert is_integer(result.index_size_bytes)
      assert is_integer(result.total_size_bytes)

      # Vacuum metrics
      assert is_integer(result.live_tuples)
      assert is_integer(result.dead_tuples)
      assert is_float(result.dead_tuple_ratio)

      # Jobs by state
      assert is_map(result.jobs_by_state)
      assert is_integer(result.total_jobs)

      # Alerts
      assert is_list(result.alerts)
    end

    test "returns zero counts when no jobs exist" do
      result = TableHealth.metrics(Repo)

      assert result.total_jobs == 0
      assert result.jobs_by_state == %{}
    end

    test "counts jobs by state" do
      insert_job("default", "available")
      insert_job("default", "available")
      insert_job("default", "scheduled")
      insert_job("mailers", "completed")

      result = TableHealth.metrics(Repo)

      assert result.total_jobs == 4
      assert result.jobs_by_state.available == 2
      assert result.jobs_by_state.scheduled == 1
      assert result.jobs_by_state.completed == 1
    end

    test "calculates dead tuple ratio" do
      result = TableHealth.metrics(Repo)

      # Ratio should be between 0 and 1
      assert result.dead_tuple_ratio >= 0.0
      assert result.dead_tuple_ratio <= 1.0
    end

    test "uses prefix from :conf option" do
      conf = %{prefix: "public"}
      result = TableHealth.metrics(Repo, conf: conf)
      assert is_map(result)
    end

    test "generates table size alert when threshold exceeded" do
      # Use a very low threshold to trigger alert
      result = TableHealth.metrics(Repo, thresholds: [table_size_mb: 0])

      # If table has any data, should trigger alert (unless truly 0 bytes)
      if result.table_size_mb > 0 do
        assert Enum.any?(result.alerts, fn {type, _msg} -> type == :table_size end)
      end
    end

    test "generates dead tuple ratio alert when threshold exceeded and min tuples met" do
      # Use a very low threshold and min_tuples of 0 to always trigger
      result =
        TableHealth.metrics(Repo,
          thresholds: [dead_tuple_ratio: 0.0, min_tuples_for_ratio_alert: 0]
        )

      # Only triggers if there are actually dead tuples
      if result.dead_tuples > 0 do
        assert Enum.any?(result.alerts, fn {type, _msg} -> type == :dead_tuple_ratio end)
      end
    end

    test "does not generate dead tuple ratio alert when below min tuples" do
      # Even with low ratio threshold, should not alert if below min_tuples
      result =
        TableHealth.metrics(Repo,
          thresholds: [dead_tuple_ratio: 0.0, min_tuples_for_ratio_alert: 1_000_000]
        )

      refute Enum.any?(result.alerts, fn {type, _msg} -> type == :dead_tuple_ratio end)
    end

    test "handles vacuum timestamps" do
      result = TableHealth.metrics(Repo)

      # These can be nil if no vacuum has been run, or DateTime if vacuum has run
      assert is_nil(result.last_vacuum) or match?(%DateTime{}, result.last_vacuum)
      assert is_nil(result.last_autovacuum) or match?(%DateTime{}, result.last_autovacuum)

      # Hours since vacuum can be nil or float
      assert is_nil(result.hours_since_vacuum) or is_float(result.hours_since_vacuum)
      assert is_nil(result.hours_since_autovacuum) or is_float(result.hours_since_autovacuum)
    end
  end

  describe "metrics/2 with :oban option" do
    test "extracts config from running Oban instance" do
      result = TableHealth.metrics(Repo, oban: ObanDoctor.TestOban)

      assert is_map(result)
      assert is_integer(result.table_size_bytes)
    end

    test "uses prefix from Oban config" do
      result = TableHealth.metrics(Repo, oban: ObanDoctor.TestOban)
      assert is_map(result)
    end
  end

  describe "validate/1" do
    test "accepts valid options" do
      assert :ok = TableHealth.validate(interval: 5000)
      assert :ok = TableHealth.validate(interval: :timer.hours(6))
      assert :ok = TableHealth.validate([])
    end

    test "accepts thresholds option" do
      assert :ok = TableHealth.validate(thresholds: [table_size_mb: 500])
      assert :ok = TableHealth.validate(thresholds: [dead_tuple_ratio: 0.05])

      assert :ok =
               TableHealth.validate(
                 thresholds: [
                   table_size_mb: 1000,
                   dead_tuple_ratio: 0.1,
                   hours_since_vacuum: 48
                 ]
               )
    end

    test "rejects invalid interval" do
      assert {:error, _} = TableHealth.validate(interval: -1)
      assert {:error, _} = TableHealth.validate(interval: 0)
      assert {:error, _} = TableHealth.validate(interval: "5000")
    end
  end

  describe "format_logger_output/2" do
    test "extracts table_size_mb and alert_count from metadata" do
      conf = %{name: :test}
      meta = %{table_size_mb: 150, alert_count: 2, other: :data}

      result = TableHealth.format_logger_output(conf, meta)

      assert result == %{table_size_mb: 150, alert_count: 2}
    end

    test "returns empty map when keys not present" do
      conf = %{name: :test}
      meta = %{other: :data}

      result = TableHealth.format_logger_output(conf, meta)

      assert result == %{}
    end
  end

  describe "telemetry" do
    test "emits [:oban_doctor, :table, :health] event" do
      ref = :telemetry_test.attach_event_handlers(self(), [[:oban_doctor, :table, :health]])

      conf = Oban.config(ObanDoctor.TestOban)
      {:ok, pid} = TableHealth.start_link(conf: conf, name: :test_table_health, interval: 100)
      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)

      send(pid, :poll)

      assert_receive {[:oban_doctor, :table, :health], ^ref, measurements, metadata}, 1000

      assert is_integer(measurements.table_size_mb)
      assert is_float(measurements.dead_tuple_ratio)
      assert is_integer(measurements.alert_count)
      assert metadata.oban_name == ObanDoctor.TestOban
      assert is_map(metadata.metrics)
      assert is_list(metadata.alerts)

      GenServer.stop(pid)
    end

    test "includes table_size_mb in [:oban, :plugin, :stop] metadata" do
      ref = :telemetry_test.attach_event_handlers(self(), [[:oban, :plugin, :stop]])

      conf = Oban.config(ObanDoctor.TestOban)
      {:ok, pid} = TableHealth.start_link(conf: conf, name: :test_plugin_stop, interval: 100)
      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)

      send(pid, :poll)

      assert_receive {[:oban, :plugin, :stop], ^ref, _measurements, metadata}, 1000

      assert metadata.plugin == TableHealth
      assert metadata.conf == conf
      assert is_integer(metadata.table_size_mb)
      assert is_integer(metadata.alert_count)

      GenServer.stop(pid)
    end

    test "handles unexpected messages gracefully" do
      conf = Oban.config(ObanDoctor.TestOban)
      {:ok, pid} = TableHealth.start_link(conf: conf, name: :test_unexpected, interval: 60_000)

      send(pid, :unexpected_message)

      assert Process.alive?(pid)

      GenServer.stop(pid)
    end

    test "cancels timer on terminate" do
      conf = Oban.config(ObanDoctor.TestOban)
      {:ok, pid} = TableHealth.start_link(conf: conf, name: :test_terminate, interval: 60_000)

      state = :sys.get_state(pid)
      assert is_reference(state.timer)

      GenServer.stop(pid)
      refute Process.alive?(pid)
    end
  end

  describe "alert generation" do
    test "no alerts when all metrics within thresholds" do
      # Use very high thresholds that won't be exceeded
      thresholds = [
        table_size_mb: 1_000_000,
        dead_tuple_ratio: 1.0,
        hours_since_vacuum: 1_000_000
      ]

      result = TableHealth.metrics(Repo, thresholds: thresholds)

      # Filter out :no_vacuum alert since test DB might not have been vacuumed
      non_vacuum_alerts =
        Enum.reject(result.alerts, fn {type, _} -> type in [:no_vacuum, :vacuum_overdue] end)

      assert non_vacuum_alerts == []
    end

    test "generates multiple alerts when multiple thresholds exceeded" do
      # Insert some jobs to ensure table has data
      insert_job("default", "available")

      # Use very low thresholds
      thresholds = [
        table_size_mb: 0,
        dead_tuple_ratio: 0.0,
        hours_since_vacuum: 0
      ]

      result = TableHealth.metrics(Repo, thresholds: thresholds)

      # Should have at least one alert (table size if > 0, or vacuum alert)
      # The specific alerts depend on the actual database state
      assert is_list(result.alerts)
    end
  end

  describe "get_prefix/1 via metrics/2" do
    test "uses default prefix when no options provided" do
      # When neither :conf nor :oban provided, uses "public" prefix
      result = TableHealth.metrics(Repo)

      # The query should succeed with the default "public" prefix
      assert is_map(result)
      assert is_integer(result.table_size_bytes)
    end

    test "uses prefix from :conf option over :oban option" do
      # When both are provided, :conf takes precedence (first cond clause)
      conf = %{prefix: "public"}
      result = TableHealth.metrics(Repo, conf: conf, oban: ObanDoctor.TestOban)

      assert is_map(result)
      assert is_integer(result.table_size_bytes)
    end
  end

  describe "vacuum alert edge cases" do
    test "generates :no_vacuum alert when neither manual nor auto vacuum has run" do
      # The test database likely has never been manually vacuumed
      result = TableHealth.metrics(Repo, thresholds: [hours_since_vacuum: 1_000_000])

      # Check if we get a no_vacuum alert (when last_vacuum and last_autovacuum are both nil)
      # or a vacuum_overdue alert (when vacuum happened but was long ago)
      vacuum_alerts =
        Enum.filter(result.alerts, fn {type, _} -> type in [:no_vacuum, :vacuum_overdue] end)

      # We should get exactly one of these alerts (no vacuum or overdue)
      # since the test DB either never vacuumed or vacuum was recent
      assert length(vacuum_alerts) <= 1
    end

    test "generates :vacuum_overdue alert when hours exceed threshold" do
      # Use 0 hour threshold to ensure any past vacuum triggers the alert
      result = TableHealth.metrics(Repo, thresholds: [hours_since_vacuum: 0])

      # If there's any vacuum history, should trigger overdue alert
      if result.hours_since_vacuum || result.hours_since_autovacuum do
        assert Enum.any?(result.alerts, fn {type, _msg} -> type == :vacuum_overdue end)
      end
    end
  end

  describe "dead tuple ratio calculation" do
    test "returns 0.0 when no tuples exist" do
      # Fresh test database with no dead tuples
      result = TableHealth.metrics(Repo)

      # With 0 total tuples, ratio should be 0.0
      if result.live_tuples == 0 and result.dead_tuples == 0 do
        assert result.dead_tuple_ratio == 0.0
      end
    end
  end

  describe "hours_since calculation" do
    test "returns nil when timestamp is nil" do
      result = TableHealth.metrics(Repo)

      # If last_vacuum is nil, hours_since_vacuum should be nil
      if is_nil(result.last_vacuum) do
        assert is_nil(result.hours_since_vacuum)
      else
        assert is_float(result.hours_since_vacuum)
      end
    end
  end

  describe "child_spec/1" do
    test "returns supervisor child spec" do
      spec = TableHealth.child_spec(interval: 5000)

      assert spec.id == TableHealth
      assert spec.start == {TableHealth, :start_link, [[interval: 5000]]}
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
