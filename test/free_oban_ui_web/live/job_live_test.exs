defmodule FreeObanUiWeb.JobLiveTest do
  use FreeObanUiWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import FreeObanUi.JobsFixtures

  alias FreeObanUi.Jobs

  describe "Index" do
    test "lists jobs with state counts", %{conn: conn} do
      job = job_fixture(worker: "MyApp.EmailWorker", args: %{"to" => "a@example.com"})
      job_fixture(state: "completed", completed_at: DateTime.utc_now())

      {:ok, view, html} = live(conn, ~p"/jobs")

      assert html =~ "MyApp.EmailWorker"
      assert html =~ "a@example.com"
      assert has_element?(view, "#job-#{job.id}")
      assert view |> element("#state-all") |> render() =~ "2"
      assert view |> element("#state-completed") |> render() =~ "1"
    end

    test "filters jobs by state", %{conn: conn} do
      available = job_fixture(state: "available")
      completed = job_fixture(state: "completed", completed_at: DateTime.utc_now())

      {:ok, view, _html} = live(conn, ~p"/jobs")

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

    test "shows an empty state", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/jobs")

      assert has_element?(view, "#no-jobs")
    end

    test "picks up new jobs on refresh", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/jobs")

      job = job_fixture()
      send(view.pid, :refresh)

      assert has_element?(view, "#job-#{job.id}")
    end
  end

  describe "Show" do
    test "displays the job", %{conn: conn} do
      job =
        job_fixture(
          worker: "MyApp.EmailWorker",
          args: %{"to" => "a@example.com"},
          state: "retryable",
          attempt: 1,
          errors: [%{attempt: 1, at: DateTime.utc_now(), error: "** (RuntimeError) boom"}]
        )

      {:ok, view, html} = live(conn, ~p"/jobs/#{job.id}")

      assert html =~ "Job #{job.id}"
      assert html =~ "MyApp.EmailWorker"
      assert view |> element("#job-args") |> render() =~ "a@example.com"
      assert view |> element("#job-errors") |> render() =~ "boom"
    end

    test "retries the job", %{conn: conn} do
      job = job_fixture(state: "discarded", discarded_at: DateTime.utc_now())

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job.id}")

      refute has_element?(view, "#cancel-job")
      assert view |> element("#retry-job") |> render_click() =~ "Job retried"
      assert %{state: "available"} = Jobs.get_job(job.id)
    end

    test "cancels the job", %{conn: conn} do
      job = job_fixture(state: "available")

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job.id}")

      refute has_element?(view, "#retry-job")
      assert view |> element("#cancel-job") |> render_click() =~ "Job cancelled"
      assert %{state: "cancelled"} = Jobs.get_job(job.id)
    end

    test "deletes the job", %{conn: conn} do
      job = job_fixture(state: "completed", completed_at: DateTime.utc_now())

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job.id}")

      {:ok, _view, html} =
        view
        |> element("#delete-job")
        |> render_click()
        |> follow_redirect(conn, ~p"/jobs")

      assert html =~ "Job deleted"
      assert Jobs.get_job(job.id) == nil
    end

    test "redirects when the job does not exist", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/jobs"}}} = live(conn, ~p"/jobs/0")
      assert {:error, {:live_redirect, %{to: "/jobs"}}} = live(conn, ~p"/jobs/abc")
    end
  end
end
