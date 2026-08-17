defmodule ObanDoctor.Plugins.IndexHealthTest do
  use ExUnit.Case, async: false

  alias ObanDoctor.Plugins.IndexHealth
  alias ObanDoctor.Test.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok
  end

  describe "metrics/2" do
    test "returns expected structure" do
      result = IndexHealth.metrics(Repo)

      # Top-level metrics
      assert is_list(result.indexes)
      assert is_integer(result.table_size_bytes)
      assert is_integer(result.total_index_size_bytes)
      assert is_float(result.index_to_table_ratio)
      assert is_list(result.alerts)
    end

    test "returns index list with expected fields" do
      result = IndexHealth.metrics(Repo)

      # oban_jobs should have at least a primary key index
      assert length(result.indexes) > 0

      for idx <- result.indexes do
        assert is_binary(idx.index_name)
        assert is_integer(idx.index_size_bytes)
        assert is_integer(idx.index_scans)
        assert is_integer(idx.tuples_read)
        assert is_integer(idx.tuples_fetched)
        assert is_boolean(idx.is_unused)
        assert is_boolean(idx.is_orphaned_reindex)
        assert is_float(idx.size_ratio)
      end
    end

    test "includes primary key index" do
      result = IndexHealth.metrics(Repo)

      index_names = Enum.map(result.indexes, & &1.index_name)
      assert "oban_jobs_pkey" in index_names
    end

    test "calculates size_ratio correctly" do
      result = IndexHealth.metrics(Repo)

      # Each index's size_ratio should be index_size / table_size
      for idx <- result.indexes do
        if result.table_size_bytes > 0 do
          expected_ratio = Float.round(idx.index_size_bytes / result.table_size_bytes, 4)
          assert idx.size_ratio == expected_ratio
        else
          assert idx.size_ratio == 0.0
        end
      end
    end

    test "calculates index_to_table_ratio correctly" do
      result = IndexHealth.metrics(Repo)

      if result.table_size_bytes > 0 do
        expected_ratio =
          Float.round(result.total_index_size_bytes / result.table_size_bytes, 4)

        assert result.index_to_table_ratio == expected_ratio
      else
        assert result.index_to_table_ratio == 0.0
      end
    end

    test "identifies unused indexes (zero scans)" do
      result = IndexHealth.metrics(Repo)

      for idx <- result.indexes do
        if idx.index_scans == 0 do
          assert idx.is_unused == true
        else
          assert idx.is_unused == false
        end
      end
    end

    test "uses prefix from :conf option" do
      conf = %{prefix: "public"}
      result = IndexHealth.metrics(Repo, conf: conf)
      assert is_map(result)
    end

    test "returns empty indexes list for non-existent schema" do
      conf = %{prefix: "nonexistent_schema"}
      result = IndexHealth.metrics(Repo, conf: conf)

      assert result.indexes == []
      assert result.table_size_bytes == 0
      assert result.total_index_size_bytes == 0
    end

    test "sorts indexes by size descending" do
      result = IndexHealth.metrics(Repo)

      if length(result.indexes) > 1 do
        sizes = Enum.map(result.indexes, & &1.index_size_bytes)
        assert sizes == Enum.sort(sizes, :desc)
      end
    end
  end

  describe "metrics/2 with :oban option" do
    test "extracts config from running Oban instance" do
      result = IndexHealth.metrics(Repo, oban: ObanDoctor.TestOban)

      assert is_map(result)
      assert is_list(result.indexes)
    end

    test "uses prefix from Oban config" do
      result = IndexHealth.metrics(Repo, oban: ObanDoctor.TestOban)
      assert is_map(result)
    end
  end

  describe "validate/1" do
    test "accepts valid options" do
      assert :ok = IndexHealth.validate(interval: 5000)
      assert :ok = IndexHealth.validate(interval: :timer.hours(6))
      assert :ok = IndexHealth.validate([])
    end

    test "rejects invalid interval" do
      assert {:error, _} = IndexHealth.validate(interval: -1)
      assert {:error, _} = IndexHealth.validate(interval: 0)
      assert {:error, _} = IndexHealth.validate(interval: "5000")
    end
  end

  describe "format_logger_output/2" do
    test "extracts index_count, orphaned_count, and alert_count from metadata" do
      conf = %{name: :test}
      meta = %{index_count: 5, orphaned_count: 1, alert_count: 2, other: :data}

      result = IndexHealth.format_logger_output(conf, meta)

      assert result == %{index_count: 5, orphaned_count: 1, alert_count: 2}
    end

    test "returns empty map when keys not present" do
      conf = %{name: :test}
      meta = %{other: :data}

      result = IndexHealth.format_logger_output(conf, meta)

      assert result == %{}
    end
  end

  describe "telemetry" do
    test "emits [:oban_doctor, :index, :health] event" do
      ref = :telemetry_test.attach_event_handlers(self(), [[:oban_doctor, :index, :health]])

      conf = Oban.config(ObanDoctor.TestOban)
      {:ok, pid} = IndexHealth.start_link(conf: conf, name: :test_index_health, interval: 100)
      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)

      send(pid, :poll)

      assert_receive {[:oban_doctor, :index, :health], ^ref, measurements, metadata}, 1000

      assert is_integer(measurements.index_count)
      assert is_integer(measurements.unused_count)
      assert is_integer(measurements.orphaned_count)
      assert is_integer(measurements.alert_count)
      assert metadata.oban_name == ObanDoctor.TestOban
      assert is_map(metadata.metrics)
      assert is_list(metadata.alerts)

      GenServer.stop(pid)
    end

    test "includes index_count in [:oban, :plugin, :stop] metadata" do
      ref = :telemetry_test.attach_event_handlers(self(), [[:oban, :plugin, :stop]])

      conf = Oban.config(ObanDoctor.TestOban)
      {:ok, pid} = IndexHealth.start_link(conf: conf, name: :test_plugin_stop, interval: 100)
      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)

      send(pid, :poll)

      assert_receive {[:oban, :plugin, :stop], ^ref, _measurements, metadata}, 1000

      assert metadata.plugin == IndexHealth
      assert metadata.conf == conf
      assert is_integer(metadata.index_count)
      assert is_integer(metadata.alert_count)

      GenServer.stop(pid)
    end

    test "handles unexpected messages gracefully" do
      conf = Oban.config(ObanDoctor.TestOban)
      {:ok, pid} = IndexHealth.start_link(conf: conf, name: :test_unexpected, interval: 60_000)

      send(pid, :unexpected_message)

      assert Process.alive?(pid)

      GenServer.stop(pid)
    end

    test "cancels timer on terminate" do
      conf = Oban.config(ObanDoctor.TestOban)
      {:ok, pid} = IndexHealth.start_link(conf: conf, name: :test_terminate, interval: 60_000)

      state = :sys.get_state(pid)
      assert is_reference(state.timer)

      GenServer.stop(pid)
      refute Process.alive?(pid)
    end
  end

  describe "alert generation" do
    test "generates unused index alert for indexes with zero scans" do
      result = IndexHealth.metrics(Repo)

      # Filter to non-orphaned unused indexes (orphaned get their own alert)
      unused_non_orphaned =
        Enum.filter(result.indexes, fn idx ->
          idx.is_unused and not idx.is_orphaned_reindex
        end)

      if length(unused_non_orphaned) > 0 do
        assert Enum.any?(result.alerts, fn {type, _msg} -> type == :unused_index end)
      end
    end

    test "unused index alert includes size in MB" do
      result = IndexHealth.metrics(Repo)

      unused_alerts = Enum.filter(result.alerts, fn {type, _} -> type == :unused_index end)

      for {_type, msg} <- unused_alerts do
        assert msg =~ "MB"
        assert msg =~ "oban_jobs"
      end
    end

    test "detects orphaned reindex indexes by _ccnew pattern" do
      result = IndexHealth.metrics(Repo)

      # Standard oban indexes should not be marked as orphaned
      for idx <- result.indexes do
        if String.ends_with?(idx.index_name, "_ccnew") or
             Regex.match?(~r/_ccnew\d+$/, idx.index_name) do
          assert idx.is_orphaned_reindex == true
        else
          assert idx.is_orphaned_reindex == false
        end
      end
    end

    test "standard oban indexes are not marked as orphaned" do
      result = IndexHealth.metrics(Repo)

      standard_indexes = [
        "oban_jobs_pkey",
        "oban_jobs_args_index",
        "oban_jobs_meta_index",
        "oban_jobs_state_queue_priority_scheduled_at_id_index"
      ]

      for idx <- result.indexes do
        if idx.index_name in standard_indexes do
          assert idx.is_orphaned_reindex == false,
                 "#{idx.index_name} should not be marked as orphaned"
        end
      end
    end
  end

  describe "get_prefix/1 via metrics/2" do
    test "uses default prefix when no options provided" do
      # When neither :conf nor :oban provided, uses "public" prefix
      result = IndexHealth.metrics(Repo)

      # The query should succeed with the default "public" prefix
      assert is_map(result)
      assert is_list(result.indexes)
    end

    test "uses prefix from :conf option over :oban option" do
      # When both are provided, :conf takes precedence (first cond clause)
      conf = %{prefix: "public"}
      result = IndexHealth.metrics(Repo, conf: conf, oban: ObanDoctor.TestOban)

      assert is_map(result)
      assert is_list(result.indexes)
    end
  end

  describe "child_spec/1" do
    test "returns supervisor child spec" do
      spec = IndexHealth.child_spec(interval: 5000)

      assert spec.id == IndexHealth
      assert spec.start == {IndexHealth, :start_link, [[interval: 5000]]}
    end
  end

  describe "edge cases" do
    test "handles table with zero size gracefully" do
      # This tests the division by zero protection
      result = IndexHealth.metrics(Repo)

      # Even if table_size is 0, should not crash and should return valid ratios
      assert is_float(result.index_to_table_ratio)

      for idx <- result.indexes do
        assert is_float(idx.size_ratio)
      end
    end

    test "total_index_size_bytes equals sum of individual index sizes" do
      result = IndexHealth.metrics(Repo)

      expected_total =
        Enum.reduce(result.indexes, 0, fn idx, acc ->
          acc + idx.index_size_bytes
        end)

      assert result.total_index_size_bytes == expected_total
    end
  end
end
