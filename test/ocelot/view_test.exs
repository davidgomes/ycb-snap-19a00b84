defmodule Ocelot.ViewTest do
  use ExUnit.Case, async: true

  alias Ocelot.View

  describe "jobs_path/2" do
    test "omits empty filters and the first page" do
      assert View.jobs_path("/oban", %{state: nil, queue: nil, page: 1}) == "/oban"

      assert View.jobs_path("/", %{state: "completed", queue: nil, page: 1}) ==
               "/?state=completed"
    end

    test "encodes filters and pages" do
      assert View.jobs_path("/oban", %{state: "available", queue: "a&b", page: 3}) ==
               "/oban?state=available&queue=a%26b&page=3"
    end
  end

  test "job_path/2 joins the mount path" do
    assert View.job_path("/", %{id: 1}) == "/jobs/1"
    assert View.job_path("/oban", %{id: 1}) == "/oban/jobs/1"
  end

  test "relative_time/2 describes past and future times" do
    now = ~U[2026-01-01 12:00:00Z]

    assert View.relative_time(now, now) == "just now"
    assert View.relative_time(DateTime.add(now, -42), now) == "42s ago"
    assert View.relative_time(DateTime.add(now, 5 * 60), now) == "in 5m"
    assert View.relative_time(DateTime.add(now, -3 * 3_600), now) == "3h ago"
    assert View.relative_time(DateTime.add(now, 2 * 86_400), now) == "in 2d"
  end

  test "job_time/1 picks the timestamp for the job state" do
    inserted_at = ~U[2026-01-01 12:00:00Z]
    completed_at = ~U[2026-01-01 12:00:05Z]

    job = %Oban.Job{state: "completed", inserted_at: inserted_at, completed_at: completed_at}
    assert View.job_time(job) == {"completed", completed_at}

    job = %Oban.Job{state: "executing", inserted_at: inserted_at, attempted_at: nil}
    assert View.job_time(job) == {"inserted", inserted_at}
  end

  test "truncate/2 shortens long strings" do
    assert View.truncate("short", 10) == "short"
    assert View.truncate("a longer string", 6) == "a lon…"
  end
end
