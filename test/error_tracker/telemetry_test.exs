defmodule ErrorTracker.TelemetryTest do
  use ErrorTracker.Test.Case

  alias ErrorTracker.Error
  alias ErrorTracker.Occurrence

  setup do
    attach_telemetry()

    :ok
  end

  test "events are emitted for new errors" do
    # Since the error is new, both the new error and new occurrence events will be emitted
    report_error(fn -> raise "This is a test" end)
    assert_receive {:telemetry_event, [:error_tracker, :error, :new], _, %{error: %Error{}}}

    assert_receive {:telemetry_event, [:error_tracker, :occurrence, :new], _,
                    %{occurrence: %Occurrence{}}}

    # The error is already known so the new error event won't be emitted
    report_error(fn -> raise "This is a test" end)

    refute_receive {:telemetry_event, [:error_tracker, :error, :new], _,
                    %{occurrence: %Occurrence{}}},
                   150

    assert_receive {:telemetry_event, [:error_tracker, :occurrence, :new], _,
                    %{occurrence: %Occurrence{}}}
  end

  test "events are emitted for resolved and unresolved errors" do
    %Occurrence{error: error = %Error{}} = report_error(fn -> raise "This is a test" end)

    # The resolved event will be emitted
    {:ok, resolved = %Error{}} = ErrorTracker.resolve(error)
    assert_receive {:telemetry_event, [:error_tracker, :error, :resolved], _, %{error: %Error{}}}

    # The unresolved event will be emitted
    {:ok, _unresolved} = ErrorTracker.unresolve(resolved)

    assert_receive {:telemetry_event, [:error_tracker, :error, :unresolved], _,
                    %{error: %Error{}}}
  end

  test "events are emitted for muted and unmuted errors" do
    %Occurrence{error: error = %Error{}} = report_error(fn -> raise "This is a test" end)

    # The muted event will be emitted
    {:ok, muted = %Error{}} = ErrorTracker.mute(error)
    assert_receive {:telemetry_event, [:error_tracker, :error, :muted], _, %{error: %Error{}}}

    # The unmuted event will be emitted
    {:ok, _unmuted} = ErrorTracker.unmute(muted)
    assert_receive {:telemetry_event, [:error_tracker, :error, :unmuted], _, %{error: %Error{}}}
  end

  test "no events are emitted for occurrences of muted errors" do
    %Occurrence{error: error = %Error{}} = report_error(fn -> raise "This is a test" end)
    {:ok, muted = %Error{}} = ErrorTracker.mute(error)

    # Ignore the events emitted while reporting and muting the error
    flush_telemetry_events()

    report_error(fn -> raise "This is a test" end)

    refute_receive {:telemetry_event, [:error_tracker, :occurrence, :new], _, _}, 150
    refute_receive {:telemetry_event, [:error_tracker, :error, :unresolved], _, _}, 150

    # Once the error is unmuted the events are emitted again
    {:ok, _unmuted} = ErrorTracker.unmute(muted)
    report_error(fn -> raise "This is a test" end)

    assert_receive {:telemetry_event, [:error_tracker, :occurrence, :new], _,
                    %{occurrence: %Occurrence{}}}
  end

  test "no events are emitted for resolved errors that are muted" do
    %Occurrence{error: error = %Error{}} = report_error(fn -> raise "This is a test" end)
    {:ok, resolved} = ErrorTracker.resolve(error)
    {:ok, _muted} = ErrorTracker.mute(resolved)

    flush_telemetry_events()

    report_error(fn -> raise "This is a test" end)

    refute_receive {:telemetry_event, [:error_tracker, :error, :unresolved], _, _}, 150
  end

  defp flush_telemetry_events do
    receive do
      {:telemetry_event, _, _, _} -> flush_telemetry_events()
    after
      0 -> :ok
    end
  end
end
