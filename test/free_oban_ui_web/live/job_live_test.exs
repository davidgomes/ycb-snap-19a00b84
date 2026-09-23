defmodule FreeObanUiWeb.JobLiveTest do
  use FreeObanUiWeb.ConnCase

  import Phoenix.LiveViewTest
  import FreeObanUi.JobsFixtures

  alias FreeObanUi.Jobs

  describe "Index" do
    test "lists jobs and counts them by state", %{conn: conn} do
      completed =
        job_fixture(%{"to" => "a@example.com"}, worker: "MyApp.Mailer", state: "completed")

      retryable = job_fixture(%{}, state: "retryable")

      {:ok, view, html} = live(conn, ~p"/jobs")

      assert html =~ "Jobs"
      assert has_element?(view, "#job-#{completed.id}", "MyApp.Mailer")
      assert has_element?(view, "#job-#{completed.id}", "a@example.com")
      assert has_element?(view, "#job-#{retryable.id}", "retryable")
      assert has_element?(view, "#state-filter-all", "2")
      assert has_element?(view, "#state-filter-completed", "1")
      assert has_element?(view, "#state-filter-executing", "0")
    end

    test "filters jobs by state", %{conn: conn} do
      completed = job_fixture(%{}, state: "completed")
      retryable = job_fixture(%{}, state: "retryable")

      {:ok, view, _html} = live(conn, ~p"/jobs")

      view |> element("#state-filter-retryable") |> render_click()

      assert_patch(view, ~p"/jobs?state=retryable")
      assert has_element?(view, "#job-#{retryable.id}")
      refute has_element?(view, "#job-#{completed.id}")

      view |> element("#state-filter-all") |> render_click()

      assert_patch(view, ~p"/jobs")
      assert has_element?(view, "#job-#{completed.id}")
    end

    test "shows all jobs for unknown states", %{conn: conn} do
      job = job_fixture()

      {:ok, view, _html} = live(conn, ~p"/jobs?state=bogus")

      assert has_element?(view, "#job-#{job.id}")
    end

    test "shows a message when there are no jobs", %{conn: conn} do
      job_fixture(%{}, state: "completed")

      {:ok, view, _html} = live(conn, ~p"/jobs?state=executing")

      assert has_element?(view, "#jobs-empty")
      refute has_element?(view, "#jobs")
    end

    test "loads more jobs on demand", %{conn: conn} do
      [oldest | _] = for _ <- 1..51, do: job_fixture()

      {:ok, view, _html} = live(conn, ~p"/jobs")

      refute has_element?(view, "#job-#{oldest.id}")
      assert render(view) =~ "Showing 50 of 51 jobs"

      view |> element("#load-more") |> render_click()

      assert has_element?(view, "#job-#{oldest.id}")
      refute has_element?(view, "#load-more")
    end

    test "picks up new jobs on refresh", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/jobs")

      job = job_fixture()
      send(view.pid, :refresh)

      assert has_element?(view, "#job-#{job.id}")
      assert has_element?(view, "#state-filter-all", "1")
    end

    test "navigates to a job", %{conn: conn} do
      job = job_fixture()

      {:ok, view, _html} = live(conn, ~p"/jobs")

      assert {:ok, _show, html} =
               view
               |> element("#job-#{job.id} td:first-child")
               |> render_click()
               |> follow_redirect(conn, ~p"/jobs/#{job.id}")

      assert html =~ "Job #{job.id}"
    end
  end

  describe "Show" do
    test "displays the job", %{conn: conn} do
      job =
        job_fixture(%{"to" => "a@example.com"},
          worker: "MyApp.Mailer",
          queue: "mailers",
          tags: ["welcome"],
          state: "retryable",
          attempt: 1,
          errors: [%{at: ~U[2024-09-10 12:00:00Z], attempt: 1, error: "** (RuntimeError) boom"}]
        )

      {:ok, view, html} = live(conn, ~p"/jobs/#{job.id}")

      assert html =~ "Job #{job.id}"
      assert html =~ "MyApp.Mailer"
      assert html =~ "mailers"
      assert html =~ "welcome"
      assert html =~ "1 of 20"
      assert has_element?(view, "#job-args", "a@example.com")
      assert has_element?(view, "#job-errors", "Attempt 1 at 2024-09-10 12:00:00 UTC")
      assert has_element?(view, "#job-errors", "** (RuntimeError) boom")
    end

    test "retries the job", %{conn: conn} do
      job = job_fixture(%{}, state: "discarded", attempt: 20)

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job.id}")

      refute has_element?(view, "#cancel-job")

      view |> element("#retry-job") |> render_click()

      assert %{state: "available"} = Jobs.get_job!(job.id)
      assert has_element?(view, "#flash-info", "Job retried")
      refute has_element?(view, "#retry-job")
    end

    test "cancels the job", %{conn: conn} do
      job = job_fixture(%{}, state: "available")

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job.id}")

      refute has_element?(view, "#retry-job")

      view |> element("#cancel-job") |> render_click()

      assert %{state: "cancelled"} = Jobs.get_job!(job.id)
      assert has_element?(view, "#flash-info", "Job cancelled")
      refute has_element?(view, "#cancel-job")
    end

    test "deletes the job", %{conn: conn} do
      job = job_fixture(%{}, state: "completed")

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job.id}")

      assert {:ok, _index, html} =
               view
               |> element("#delete-job")
               |> render_click()
               |> follow_redirect(conn, ~p"/jobs")

      assert html =~ "Job deleted"
      assert Jobs.get_job(job.id) == nil
    end

    test "only allows cancelling executing jobs", %{conn: conn} do
      job = job_fixture(%{}, state: "executing")

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job.id}")

      assert has_element?(view, "#cancel-job")
      refute has_element?(view, "#retry-job")
      refute has_element?(view, "#delete-job")
    end

    test "redirects when the job no longer exists", %{conn: conn} do
      job = job_fixture()

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job.id}")

      :ok = Jobs.delete_job(job)
      send(view.pid, :refresh)

      {path, flash} = assert_redirect(view)
      assert path == ~p"/jobs"
      assert flash["info"] =~ "no longer exists"
    end

    test "raises for unknown jobs", %{conn: conn} do
      assert_raise Ecto.NoResultsError, fn -> live(conn, ~p"/jobs/0") end
    end
  end
end
