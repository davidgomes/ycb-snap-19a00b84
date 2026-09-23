defmodule FreeObanUiWeb.JobLiveTest do
  use FreeObanUiWeb.ConnCase

  import Phoenix.LiveViewTest
  import FreeObanUi.JobsFixtures

  alias FreeObanUi.Jobs
  alias FreeObanUi.Repo

  describe "Index" do
    test "lists jobs and counts them by state", %{conn: conn} do
      job = job_fixture(args: %{"email" => "user@example.com"})
      job_fixture(state: "completed", completed_at: DateTime.utc_now())

      {:ok, view, _html} = live(conn, ~p"/jobs")

      assert has_element?(view, "#job-#{job.id}", "FreeObanUi.Workers.ExampleWorker")
      assert has_element?(view, "#job-#{job.id}", "user@example.com")
      assert has_element?(view, "#state-filter-all", "2")
      assert has_element?(view, "#state-filter-available", "1")
      assert has_element?(view, "#state-filter-completed", "1")
      assert has_element?(view, "#state-filter-discarded", "0")
    end

    test "shows a message when there are no jobs", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/jobs")

      assert has_element?(view, "#jobs-empty", "No jobs found")
    end

    test "filters jobs by state", %{conn: conn} do
      available = job_fixture()
      completed = job_fixture(state: "completed")

      {:ok, view, _html} = live(conn, ~p"/jobs")

      view |> element("#state-filter-completed") |> render_click()
      assert_patch(view, ~p"/jobs?state=completed")

      assert has_element?(view, "#job-#{completed.id}")
      refute has_element?(view, "#job-#{available.id}")
    end

    test "filters jobs by queue", %{conn: conn} do
      default = job_fixture(queue: "default")
      mailer = job_fixture(queue: "mailers")

      {:ok, view, _html} = live(conn, ~p"/jobs")

      view |> form("#queue-filter", queue: "mailers") |> render_change()
      assert_patch(view, ~p"/jobs?queue=mailers")

      assert has_element?(view, "#job-#{mailer.id}")
      refute has_element?(view, "#job-#{default.id}")
      assert has_element?(view, "#state-filter-all", "1")
    end

    test "combines state and queue filters from the URL", %{conn: conn} do
      job_fixture(queue: "mailers")
      completed_mailer = job_fixture(queue: "mailers", state: "completed")
      job_fixture(queue: "default", state: "completed")

      {:ok, view, _html} = live(conn, ~p"/jobs?#{[queue: "mailers", state: "completed"]}")

      assert [_] = view |> render() |> Floki.parse_document!() |> Floki.find("#jobs tr")
      assert has_element?(view, "#job-#{completed_mailer.id}")
    end

    test "ignores unknown states", %{conn: conn} do
      job = job_fixture()

      {:ok, view, _html} = live(conn, ~p"/jobs?state=unknown")

      assert has_element?(view, "#job-#{job.id}")
    end

    test "only offers the actions allowed for each job", %{conn: conn} do
      available = job_fixture()
      completed = job_fixture(state: "completed")

      {:ok, view, _html} = live(conn, ~p"/jobs")

      assert has_element?(view, "#job-#{available.id} a", "Cancel")
      refute has_element?(view, "#job-#{available.id} a", "Retry")
      assert has_element?(view, "#job-#{completed.id} a", "Retry")
      refute has_element?(view, "#job-#{completed.id} a", "Cancel")
    end

    test "retries a job", %{conn: conn} do
      job = job_fixture(state: "discarded", discarded_at: DateTime.utc_now())

      {:ok, view, _html} = live(conn, ~p"/jobs")

      assert view |> element("#job-#{job.id} a", "Retry") |> render_click() =~
               "Job #{job.id} will be retried"

      assert Jobs.get_job!(job.id).state == "available"
      assert has_element?(view, "#job-#{job.id}", "available")
    end

    test "cancels a job", %{conn: conn} do
      job = job_fixture()

      {:ok, view, _html} = live(conn, ~p"/jobs")

      assert view |> element("#job-#{job.id} a", "Cancel") |> render_click() =~
               "Job #{job.id} cancelled"

      assert Jobs.get_job!(job.id).state == "cancelled"
    end

    test "reports actions on jobs that no longer exist", %{conn: conn} do
      job = job_fixture(state: "completed")

      {:ok, view, _html} = live(conn, ~p"/jobs")
      Repo.delete!(job)

      assert view |> element("#job-#{job.id} a", "Retry") |> render_click() =~
               "Job #{job.id} no longer exists"
    end

    test "refreshes the jobs periodically", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/jobs")

      job = job_fixture()
      refute has_element?(view, "#job-#{job.id}")

      send(view.pid, :refresh)
      assert has_element?(view, "#job-#{job.id}")
    end

    test "navigates to a job when its row is clicked", %{conn: conn} do
      job = job_fixture()

      {:ok, view, _html} = live(conn, ~p"/jobs")

      assert {:error, {:live_redirect, %{to: path}}} =
               view |> element("#job-#{job.id} td:first-child") |> render_click()

      assert path == ~p"/jobs/#{job.id}"
    end
  end

  describe "Show" do
    test "displays the job", %{conn: conn} do
      job =
        job_fixture(
          args: %{"email" => "user@example.com"},
          meta: %{"source" => "signup"},
          tags: ["welcome"]
        )

      {:ok, view, html} = live(conn, ~p"/jobs/#{job.id}")

      assert html =~ "Job #{job.id}"
      assert html =~ "FreeObanUi.Workers.ExampleWorker"
      assert html =~ "welcome"
      assert has_element?(view, "#job-args", ~s("email": "user@example.com"))
      assert has_element?(view, "#job-meta", ~s("source": "signup"))
      assert has_element?(view, "#job-errors", "No errors recorded")
    end

    test "lists errors with the most recent attempt first", %{conn: conn} do
      job =
        job_fixture(
          state: "retryable",
          attempt: 2,
          errors: [
            %{"attempt" => 1, "at" => "2024-09-01T12:00:00Z", "error" => "first failure"},
            %{"attempt" => 2, "at" => "2024-09-01T12:05:00Z", "error" => "second failure"}
          ]
        )

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job.id}")

      errors = view |> element("#job-errors") |> render()

      assert errors =~ "2024-09-01 12:05:00 UTC"
      assert [_, after_second] = String.split(errors, "second failure")
      assert after_second =~ "first failure"
    end

    test "retries the job", %{conn: conn} do
      job = job_fixture(state: "discarded", discarded_at: DateTime.utc_now())

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job.id}")

      assert view |> element("#retry-job") |> render_click() =~ "Job will be retried"
      assert Jobs.get_job!(job.id).state == "available"
      refute has_element?(view, "#retry-job")
      assert has_element?(view, "#cancel-job")
    end

    test "cancels the job", %{conn: conn} do
      job = job_fixture(schedule_in: 60)

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job.id}")

      assert view |> element("#cancel-job") |> render_click() =~ "Job cancelled"
      assert Jobs.get_job!(job.id).state == "cancelled"
      refute has_element?(view, "#cancel-job")
      assert has_element?(view, "#retry-job")
    end

    test "picks up changes to the job when refreshing", %{conn: conn} do
      job = job_fixture()

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job.id}")

      :ok = Jobs.cancel_job(job)
      send(view.pid, :refresh)

      assert has_element?(view, "#retry-job")
    end

    test "redirects to the jobs list once the job is gone", %{conn: conn} do
      job = job_fixture()

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job.id}")

      Repo.delete!(job)
      send(view.pid, :refresh)

      flash = assert_redirect(view, ~p"/jobs")
      assert flash["error"] == "Job #{job.id} no longer exists"
    end

    test "raises when the job does not exist", %{conn: conn} do
      assert_raise Ecto.NoResultsError, fn -> live(conn, ~p"/jobs/0") end
    end
  end
end
