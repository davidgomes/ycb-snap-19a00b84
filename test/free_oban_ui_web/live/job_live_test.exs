defmodule FreeObanUiWeb.JobLiveTest do
  use FreeObanUiWeb.ConnCase

  import Phoenix.LiveViewTest
  import FreeObanUi.JobsFixtures

  alias FreeObanUi.Jobs

  describe "Index" do
    test "lists jobs with state counts", %{conn: conn} do
      job = job_fixture(worker: "MyApp.EmailWorker", state: "completed")

      {:ok, view, html} = live(conn, ~p"/jobs")

      assert html =~ "MyApp.EmailWorker"
      assert has_element?(view, "#jobs-#{job.id}")
      assert view |> element("#state-filter-completed") |> render() =~ "1"
    end

    test "shows an empty message when there are no jobs", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/jobs")

      assert has_element?(view, "#jobs-empty")
    end

    test "filters by state", %{conn: conn} do
      completed = job_fixture(state: "completed")
      discarded = job_fixture(state: "discarded")

      {:ok, view, _html} = live(conn, ~p"/jobs")

      view |> element("#state-filter-discarded") |> render_click()

      assert_patched(view, ~p"/jobs?state=discarded")
      assert has_element?(view, "#jobs-#{discarded.id}")
      refute has_element?(view, "#jobs-#{completed.id}")
    end

    test "filters by queue", %{conn: conn} do
      default = job_fixture(queue: "default")
      mailer = job_fixture(queue: "mailers")

      {:ok, view, _html} = live(conn, ~p"/jobs")

      view |> form("#queue-filter", %{queue: "mailers"}) |> render_change()

      assert_patched(view, ~p"/jobs?queue=mailers")
      assert has_element?(view, "#jobs-#{mailer.id}")
      refute has_element?(view, "#jobs-#{default.id}")
    end

    test "picks up new jobs on refresh", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/jobs")

      job = job_fixture()
      send(view.pid, :refresh)

      assert has_element?(view, "#jobs-#{job.id}")
    end
  end

  describe "Show" do
    test "displays job details", %{conn: conn} do
      job = job_fixture(worker: "MyApp.EmailWorker", args: %{"user_id" => 42})

      {:ok, view, html} = live(conn, ~p"/jobs/#{job.id}")

      assert html =~ "Job #{job.id}"
      assert html =~ "MyApp.EmailWorker"
      assert view |> element("#job-args") |> render() =~ "user_id"
    end

    test "retries a discarded job", %{conn: conn} do
      job = job_fixture(state: "discarded")

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job.id}")

      assert view |> element("#retry-job") |> render_click() =~ "Job retried"
      assert Jobs.get_job(job.id).state == "available"
    end

    test "cancels an available job", %{conn: conn} do
      job = job_fixture(state: "available")

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job.id}")

      assert view |> element("#cancel-job") |> render_click() =~ "Job cancelled"
      assert Jobs.get_job(job.id).state == "cancelled"
    end

    test "deletes a job", %{conn: conn} do
      job = job_fixture(state: "completed")

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job.id}")

      assert {:error, {:live_redirect, %{to: "/jobs"}}} =
               view |> element("#delete-job") |> render_click()

      assert Jobs.get_job(job.id) == nil
    end

    test "redirects when the job doesn't exist", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/jobs", flash: %{"error" => "Job not found"}}}} =
               live(conn, ~p"/jobs/0")
    end
  end
end
