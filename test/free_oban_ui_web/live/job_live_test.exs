defmodule FreeObanUiWeb.JobLiveTest do
  use FreeObanUiWeb.ConnCase

  import Phoenix.LiveViewTest
  import FreeObanUi.JobsFixtures

  alias FreeObanUi.Jobs

  describe "Index" do
    test "lists jobs", %{conn: conn} do
      job = job_fixture(worker: "MyApp.Workers.Mailer", queue: "mailers")

      {:ok, view, html} = live(conn, ~p"/jobs")

      assert html =~ "Jobs"
      assert has_element?(view, "#job-#{job.id}", "MyApp.Workers.Mailer")
      assert has_element?(view, "#job-#{job.id}", "mailers")
    end

    test "shows an empty message without jobs", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/jobs")

      assert has_element?(view, "#jobs-empty")
    end

    test "filters jobs by state", %{conn: conn} do
      available = job_fixture()
      completed = job_fixture(state: "completed", completed_at: DateTime.utc_now())

      {:ok, view, _html} = live(conn, ~p"/jobs")

      assert has_element?(view, "#state-completed", "1")

      view |> element("#state-completed") |> render_click()
      assert_patch(view, ~p"/jobs?state=completed")

      assert has_element?(view, "#job-#{completed.id}")
      refute has_element?(view, "#job-#{available.id}")
    end

    test "ignores unknown states", %{conn: conn} do
      job = job_fixture()

      {:ok, view, _html} = live(conn, ~p"/jobs?state=bogus")

      assert has_element?(view, "#job-#{job.id}")
    end

    test "picks up new jobs on refresh", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/jobs")

      job = job_fixture()
      send(view.pid, :refresh)

      assert has_element?(view, "#job-#{job.id}")
    end

    test "navigates to a job", %{conn: conn} do
      job = job_fixture()

      {:ok, view, _html} = live(conn, ~p"/jobs")

      view |> element("#job-#{job.id} td:first-child") |> render_click()
      assert_redirect(view, ~p"/jobs/#{job.id}")
    end
  end

  describe "Show" do
    test "displays job details", %{conn: conn} do
      job =
        job_fixture(
          args: %{"email" => "david@example.com"},
          state: "retryable",
          attempt: 1,
          errors: [%{"attempt" => 1, "at" => "2024-09-20T00:00:00Z", "error" => "** boom"}]
        )

      {:ok, view, html} = live(conn, ~p"/jobs/#{job.id}")

      assert html =~ "Job #{job.id}"
      assert html =~ "FreeObanUi.FakeWorker"
      assert has_element?(view, "#job-args", "david@example.com")
      assert has_element?(view, "#job-errors", "** boom")
    end

    test "retries a job", %{conn: conn} do
      job = job_fixture(state: "discarded", discarded_at: DateTime.utc_now())

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job.id}")

      assert view |> element("#retry-job") |> render_click() =~ "Job retried"
      assert %{state: "available"} = Jobs.get_job(job.id)
      refute has_element?(view, "#retry-job")
    end

    test "cancels a job", %{conn: conn} do
      job = job_fixture()

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job.id}")

      refute has_element?(view, "#retry-job")
      assert view |> element("#cancel-job") |> render_click() =~ "Job cancelled"
      assert %{state: "cancelled"} = Jobs.get_job(job.id)
      refute has_element?(view, "#cancel-job")
    end

    test "deletes a job", %{conn: conn} do
      job = job_fixture()

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job.id}")

      view |> element("#delete-job") |> render_click()
      assert_redirect(view, ~p"/jobs")
      assert Jobs.get_job(job.id) == nil
    end

    test "redirects when the job disappears", %{conn: conn} do
      job = job_fixture()

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job.id}")

      {:ok, _job} = Jobs.delete_job(job)
      send(view.pid, :refresh)

      assert_redirect(view, ~p"/jobs")
    end

    test "raises for a missing job", %{conn: conn} do
      assert_raise Ecto.NoResultsError, fn -> live(conn, ~p"/jobs/0") end
    end
  end
end
