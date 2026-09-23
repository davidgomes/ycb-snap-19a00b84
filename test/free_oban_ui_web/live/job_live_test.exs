defmodule FreeObanUiWeb.JobLiveTest do
  use FreeObanUiWeb.ConnCase

  import Phoenix.LiveViewTest
  import FreeObanUi.JobsFixtures

  alias FreeObanUi.Jobs

  describe "Index" do
    test "lists jobs", %{conn: conn} do
      job = job_fixture(%{args: %{"user_id" => 42}})

      {:ok, view, html} = live(conn, ~p"/jobs")

      assert html =~ "Jobs"
      assert has_element?(view, "#job-#{job.id}", "FreeObanUi.Workers.ExampleWorker")
      assert has_element?(view, "#job-#{job.id}", ~s({"user_id":42}))
    end

    test "shows an empty message without jobs", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/jobs")

      assert has_element?(view, "#jobs-empty")
    end

    test "filters by state tab", %{conn: conn} do
      completed = job_fixture(%{state: "completed"})
      available = job_fixture(%{state: "available"})

      {:ok, view, _html} = live(conn, ~p"/jobs")

      view |> element("#state-tabs a", "Completed") |> render_click()
      assert_patch(view, ~p"/jobs?state=completed")

      assert has_element?(view, "#job-#{completed.id}")
      refute has_element?(view, "#job-#{available.id}")
    end

    test "filters by queue and worker search", %{conn: conn} do
      mailer = job_fixture(%{queue: "mailers", worker: "MyApp.Mailer"})
      other = job_fixture(%{queue: "default"})

      {:ok, view, _html} = live(conn, ~p"/jobs")

      view |> form("#job-filters", filters: %{queue: "mailers"}) |> render_change()
      assert_patch(view, ~p"/jobs?queue=mailers")
      assert has_element?(view, "#job-#{mailer.id}")
      refute has_element?(view, "#job-#{other.id}")

      {:ok, view, _html} = live(conn, ~p"/jobs")

      view |> form("#job-filters", filters: %{search: "mailer"}) |> render_change()
      assert_patch(view, ~p"/jobs?search=mailer")
      assert has_element?(view, "#job-#{mailer.id}")
      refute has_element?(view, "#job-#{other.id}")
    end

    test "picks up new jobs on refresh", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/jobs")

      job = job_fixture()
      send(view.pid, :refresh)

      assert has_element?(view, "#job-#{job.id}")
    end
  end

  describe "Show" do
    test "displays job details and errors", %{conn: conn} do
      job =
        job_fixture(%{
          state: "retryable",
          attempt: 1,
          args: %{"user_id" => 42},
          errors: [%{"attempt" => 1, "at" => "2024-08-01T00:00:00Z", "error" => "boom"}]
        })

      {:ok, view, html} = live(conn, ~p"/jobs/#{job.id}")

      assert html =~ "Job #{job.id}"
      assert has_element?(view, "#job-args", "user_id")
      assert has_element?(view, "#job-errors", "boom")
    end

    test "retries a discarded job", %{conn: conn} do
      job = job_fixture(%{state: "discarded", attempt: 20})

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job.id}")

      refute has_element?(view, "#cancel-job")
      assert view |> element("#retry-job") |> render_click() =~ "Job retried"
      assert %{state: "available"} = Jobs.get_job(job.id)
    end

    test "cancels an available job", %{conn: conn} do
      job = job_fixture()

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job.id}")

      assert view |> element("#cancel-job") |> render_click() =~ "Job cancelled"
      assert %{state: "cancelled"} = Jobs.get_job(job.id)
    end

    test "deletes a job", %{conn: conn} do
      job = job_fixture(%{state: "completed"})

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job.id}")

      view |> element("#delete-job") |> render_click()
      assert_redirect(view, ~p"/jobs")
      assert Jobs.get_job(job.id) == nil
    end

    test "redirects when the job does not exist", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/jobs"}}} = live(conn, ~p"/jobs/0")
    end
  end
end
