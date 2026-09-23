defmodule FreeObanUiWeb.JobComponentsTest do
  use ExUnit.Case, async: true

  import FreeObanUiWeb.JobComponents

  @now ~U[2024-09-23 12:00:00Z]

  test "format_relative/2 describes past and future times" do
    assert format_relative(@now, @now) == "now"
    assert format_relative(DateTime.add(@now, -45), @now) == "45s ago"
    assert format_relative(DateTime.add(@now, 90), @now) == "in 1m"
    assert format_relative(DateTime.add(@now, -2 * 3_600), @now) == "2h ago"
    assert format_relative(DateTime.add(@now, 3 * 86_400), @now) == "in 3d"
  end

  test "format_datetime/1 formats a UTC datetime to the second" do
    assert format_datetime(~U[2024-09-23 12:34:56.123456Z]) == "2024-09-23 12:34:56 UTC"
  end

  test "state_timestamp/1 returns the timestamp for the job's state" do
    job = %Oban.Job{
      scheduled_at: ~U[2024-09-23 12:00:00Z],
      attempted_at: ~U[2024-09-23 12:01:00Z],
      completed_at: ~U[2024-09-23 12:02:00Z],
      cancelled_at: ~U[2024-09-23 12:03:00Z],
      discarded_at: ~U[2024-09-23 12:04:00Z]
    }

    assert state_timestamp(%{job | state: "scheduled"}) == job.scheduled_at
    assert state_timestamp(%{job | state: "available"}) == job.scheduled_at
    assert state_timestamp(%{job | state: "retryable"}) == job.scheduled_at
    assert state_timestamp(%{job | state: "executing"}) == job.attempted_at
    assert state_timestamp(%{job | state: "completed"}) == job.completed_at
    assert state_timestamp(%{job | state: "cancelled"}) == job.cancelled_at
    assert state_timestamp(%{job | state: "discarded"}) == job.discarded_at
  end
end
