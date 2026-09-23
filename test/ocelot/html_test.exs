defmodule Ocelot.HTMLTest do
  use ExUnit.Case, async: true

  alias Ocelot.HTML

  defp job(attrs \\ []) do
    struct!(
      %Oban.Job{
        id: 1,
        worker: "MyApp.Worker",
        queue: "default",
        state: "completed",
        args: %{"user_id" => 42},
        meta: %{},
        tags: [],
        errors: [],
        attempt: 1,
        max_attempts: 20,
        inserted_at: ~U[2026-01-02 03:04:05.123456Z]
      },
      attrs
    )
  end

  describe "index/6" do
    test "lists jobs with links to their detail page" do
      html = HTML.index([job()], %{"completed" => 1}, nil, 1, 1, "/oban")

      assert html =~ ~s(<a href="/oban/jobs/1">1</a>)
      assert html =~ "MyApp.Worker"
      assert html =~ "{&quot;user_id&quot;:42}"
      assert html =~ "2026-01-02T03:04:05Z"
      assert html =~ "Page 1 of 1"
    end

    test "renders a tab per state with counts, highlighting the current one" do
      html = HTML.index([], %{"completed" => 3, "retryable" => 2}, "retryable", 1, 1, "")

      assert html =~ ~s(<a href="/">all (5\))
      assert html =~ ~s(<a href="/?state=completed">completed (3\))
      assert html =~ ~s(<a href="/?state=retryable" class="active">retryable (2\))
      assert html =~ ~s(<a href="/?state=discarded">discarded (0\))
      assert html =~ "No jobs found."
    end

    test "links to adjacent pages keeping the state filter" do
      html = HTML.index([job()], %{}, "completed", 2, 3, "")

      assert html =~ ~s(href="/?state=completed">&larr; Previous)
      assert html =~ ~s(href="/?state=completed&amp;page=3">Next &rarr;)
    end

    test "escapes job values" do
      html = HTML.index([job(worker: "<script>alert(1)</script>")], %{}, nil, 1, 1, "")

      refute html =~ "<script>"
      assert html =~ "&lt;script&gt;alert(1)&lt;/script&gt;"
    end
  end

  describe "job/2" do
    test "renders job details, args and errors" do
      job =
        job(
          state: "retryable",
          tags: ["a", "b"],
          errors: [
            %{"attempt" => 1, "at" => "2026-01-02T03:04:06Z", "error" => "** (RuntimeError) boom"}
          ]
        )

      html = HTML.job(job, "/oban")

      assert html =~ "<h1>Job 1</h1>"
      assert html =~ ~s(<a href="/oban/">&larr; All jobs</a>)
      assert html =~ "a, b"
      assert html =~ "&quot;user_id&quot;: 42"
      assert html =~ "Attempt 1 at 2026-01-02T03:04:06Z"
      assert html =~ "** (RuntimeError) boom"
    end

    test "shows a placeholder when there are no errors" do
      assert HTML.job(job(), "") =~ "No errors."
    end
  end
end
