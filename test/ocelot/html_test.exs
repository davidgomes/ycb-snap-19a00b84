defmodule Ocelot.HTMLTest do
  use ExUnit.Case, async: true

  alias Ocelot.HTML

  @now ~U[2026-01-01 12:00:00.000000Z]

  defp job(attrs) do
    struct!(
      %Oban.Job{
        id: 1,
        state: "completed",
        queue: "default",
        worker: "MyApp.Worker",
        args: %{},
        attempt: 1,
        max_attempts: 20,
        inserted_at: @now,
        scheduled_at: @now,
        attempted_at: @now,
        completed_at: @now
      },
      attrs
    )
  end

  defp jobs_assigns(attrs) do
    Map.merge(
      %{
        base: "/oban",
        oban: Oban,
        title: "Jobs",
        state: nil,
        counts: [{"available", 0}, {"completed", 1}],
        all_count: 1,
        jobs: [job(%{})],
        page: 1,
        total_pages: 1
      },
      Map.new(attrs)
    )
  end

  describe "escape/1" do
    test "escapes HTML in values" do
      assert HTML.escape("<b>&\"'") == "&lt;b&gt;&amp;&quot;&#39;"
      assert HTML.escape(42) == "42"
      assert HTML.escape(nil) == ""
    end

    test "leaves safe markup untouched" do
      assert HTML.escape(HTML.raw("<b>")) == "<b>"
      assert HTML.escape([HTML.raw("<i>"), "<"]) == "<i>&lt;"
    end
  end

  describe "render/2 :jobs" do
    test "lists jobs with links relative to the mount path" do
      html = HTML.render(:jobs, jobs_assigns([]))

      assert html =~ "<title>Jobs · Ocelot</title>"
      assert html =~ ~s(<a href="/oban/jobs/1">1</a>)
      assert html =~ ~s(href="/oban/?state=completed")
      assert html =~ "MyApp.Worker"
    end

    test "escapes job data" do
      jobs = [job(%{args: %{"html" => "<script>alert(1)</script>"}, worker: "<Worker>"})]
      html = HTML.render(:jobs, jobs_assigns(jobs: jobs))

      refute html =~ "<script>"
      refute html =~ "<Worker>"
      assert html =~ "&lt;Worker&gt;"
    end

    test "shows an empty state" do
      assert HTML.render(:jobs, jobs_assigns(jobs: [])) =~ "No jobs found."
    end

    test "paginates within the selected state" do
      html = HTML.render(:jobs, jobs_assigns(state: "completed", page: 2, total_pages: 3))

      assert html =~ "Page 2 of 3"
      assert html =~ ~s(href="/oban/?state=completed&amp;page=1")
      assert html =~ ~s(href="/oban/?state=completed&amp;page=3")
    end
  end

  describe "render/2 :job" do
    test "shows job details and errors, newest first" do
      errors = [
        %{"attempt" => 1, "at" => "2026-01-01T11:00:00Z", "error" => "first <failure>"},
        %{"attempt" => 2, "at" => "2026-01-01T11:30:00Z", "error" => "second failure"}
      ]

      html =
        HTML.render(:job, %{
          base: "",
          oban: Oban,
          title: "Job 1",
          job: job(%{state: "retryable", args: %{"id" => 7}, tags: ["a", "b"], errors: errors})
        })

      assert html =~ ~s(<a href="/?state=retryable">)
      assert html =~ "a, b"
      assert html =~ "&quot;id&quot;: 7"
      assert html =~ "first &lt;failure&gt;"
      assert :binary.match(html, "second failure") < :binary.match(html, "first &lt;failure&gt;")
    end

    test "shows when there are no errors" do
      html = HTML.render(:job, %{base: "", oban: Oban, title: "Job 1", job: job(%{})})

      assert html =~ "No errors."
    end
  end

  test "state_timestamp/1 picks the timestamp matching the state" do
    at = ~U[2026-01-01 13:00:00Z]

    assert HTML.state_timestamp(job(%{state: "scheduled", scheduled_at: at})) == {"scheduled", at}
    assert HTML.state_timestamp(job(%{state: "executing", attempted_at: at})) == {"attempted", at}
    assert HTML.state_timestamp(job(%{state: "discarded", discarded_at: at})) == {"discarded", at}
  end

  test "relative_time/2" do
    assert HTML.relative_time(nil, @now) == "—"
    assert HTML.relative_time(@now, @now) == "now"
    assert HTML.relative_time(DateTime.add(@now, -45), @now) == "45s ago"
    assert HTML.relative_time(DateTime.add(@now, 300), @now) == "in 5m"
    assert HTML.relative_time(DateTime.add(@now, -7_200), @now) == "2h ago"
    assert HTML.relative_time(DateTime.add(@now, 3 * 86_400), @now) == "in 3d"
  end

  test "jobs_path/2 drops empty params" do
    assert HTML.jobs_path("", []) == "/"
    assert HTML.jobs_path("/oban", state: nil, page: 2) == "/oban/?page=2"
  end
end
