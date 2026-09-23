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
                    %{occurrence: %Occurrence{}, error: %Error{}, muted: false}}

    # The error is already known so the new error event won't be emitted
    report_error(fn -> raise "This is a test" end)

    refute_receive {:telemetry_event, [:error_tracker, :error, :new], _,
                    %{occurrence: %Occurrence{}}},
                   150

    assert_receive {:telemetry_event, [:error_tracker, :occurrence, :new], _,
                    %{occurrence: %Occurrence{}, error: %Error{}, muted: false}}
  end

  test "new occurrence events include the muted flag of the error" do
    %Occurrence{error: error = %Error{}} = report_error(fn -> raise "This is a test" end)
    assert_receive {:telemetry_event, [:error_tracker, :occurrence, :new], _, %{muted: false}}

    # The occurrence event is still emitted for muted errors, but flagged as muted
    {:ok, muted = %Error{}} = ErrorTracker.mute(error)
    report_error(fn -> raise "This is a test" end)

    assert_receive {:telemetry_event, [:error_tracker, :occurrence, :new], _,
                    %{occurrence: %Occurrence{}, error: %Error{muted: true}, muted: true}}

    # Once unmuted, the occurrence event is no longer flagged as muted
    {:ok, _unmuted} = ErrorTracker.unmute(muted)
    report_error(fn -> raise "This is a test" end)

    assert_receive {:telemetry_event, [:error_tracker, :occurrence, :new], _,
                    %{occurrence: %Occurrence{}, error: %Error{muted: false}, muted: false}}
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
end
