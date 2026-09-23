defmodule Ocelot.HTMLTest do
  use ExUnit.Case, async: true

  alias Ocelot.HTML

  defp job(attrs) do
    struct!(
      %Oban.Job{
        id: 1,
        state: "available",
        queue: "default",
        worker: "MyApp.Worker",
        args: %{},
        meta: %{},
        tags: [],
        errors: [],
        attempt: 0,
        max_attempts: 20,
        priority: 0,
        inserted_at: ~U[2026-01-01 00:00:00.000000Z],
        scheduled_at: ~U[2026-01-01 00:00:00.000000Z]
      },
      attrs
    )
  end

  test "job_list renders jobs, state counts and pagination links" do
    counts = %{"available" => 2, "completed" => 3}
    html = HTML.job_list([job(id: 42)], counts, "available", 2, 3, "/oban")

    assert html =~ ~s(href="/oban/jobs/42")
    assert html =~ "all (5)"
    assert html =~ "completed (3)"
    assert html =~ ~s(href="/oban/jobs?state=available&amp;page=1")
    assert html =~ ~s(href="/oban/jobs?state=available&amp;page=3")
    assert html =~ "Page 2 of 3"
  end

  test "job_list shows an empty state" do
    assert HTML.job_list([], %{}, nil, 1, 1, "") =~ "No jobs found."
  end

  test "job_detail escapes user data" do
    job =
      job(
        args: %{"html" => "<script>alert(1)</script>"},
        errors: [%{"attempt" => 1, "at" => "2026-01-01T00:00:00Z", "error" => "<b>boom</b>"}]
      )

    html = HTML.job_detail(job, "/oban")

    refute html =~ "<script>alert(1)</script>"
    refute html =~ "<b>boom</b>"
    assert html =~ "&lt;script&gt;"
    assert html =~ "&lt;b&gt;boom&lt;/b&gt;"
  end
end
