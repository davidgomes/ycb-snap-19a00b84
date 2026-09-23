defmodule FreeObanUiWeb.JobLiveTest do
  use FreeObanUiWeb.ConnCase

  import Ecto.Query, only: [where: 2]
  import Phoenix.LiveViewTest
  import FreeObanUi.JobsFixtures

  alias FreeObanUi.Jobs
  alias FreeObanUi.Repo

  defp mark_executing(job) do
    Repo.update_all(where(Oban.Job, id: ^job.id), set: [state: "executing", attempt: 1])
  end

  describe "Index" do
    test "lists jobs with their state counts", %{conn: conn} do
      job = job_fixture(worker: "MyApp.EmailWorker", args: %{"to" => "david@example.com"})
      job_fixture(state: "completed", completed_at: DateTime.utc_now())

      {:ok, view, html} = live(conn, ~p"/jobs")

      assert html =~ "Jobs"
      assert has_element?(view, "#job-#{job.id}", "MyApp.EmailWorker")
      assert has_element?(view, "#job-#{job.id}", "david@example.com")
      assert has_element?(view, "#state-tab-all", "2")
      assert has_element?(view, "#state-tab-available", "1")
      assert has_element?(view, "#state-tab-completed", "1")
      assert has_element?(view, "#state-tab-executing", "0")
    end

    test "shows an empty state without jobs", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/jobs")

      assert has_element?(view, "#jobs-empty", "No jobs found")
    end

    test "filters jobs by state", %{conn: conn} do
      available = job_fixture()
      completed = job_fixture(state: "completed", completed_at: DateTime.utc_now())

      {:ok, view, _html} = live(conn, ~p"/jobs")

      view |> element("#state-tab-completed") |> render_click()

      assert_patch(view, ~p"/jobs?state=completed")
      assert has_element?(view, "#job-#{completed.id}")
      refute has_element?(view, "#job-#{available.id}")
    end

    test "shows all jobs for an unknown state", %{conn: conn} do
      job = job_fixture()

      {:ok, view, _html} = live(conn, ~p"/jobs?state=unknown")

      assert has_element?(view, "#job-#{job.id}")
    end

    test "paginates jobs", %{conn: conn} do
      [oldest | _] = for _ <- 1..21, do: job_fixture()

      {:ok, view, _html} = live(conn, ~p"/jobs")

      assert has_element?(view, "#jobs-pagination", "Page 1 of 2")
      refute has_element?(view, "#job-#{oldest.id}")

      view |> element("#jobs-pagination a", "Next") |> render_click()

      assert_patch(view, ~p"/jobs?page=2")
      assert has_element?(view, "#job-#{oldest.id}")
    end

    test "only offers actions allowed for the job's state", %{conn: conn} do
      executing = job_fixture(state: "executing", attempt: 1, attempted_at: DateTime.utc_now())
      scheduled = job_fixture(state: "scheduled", scheduled_at: DateTime.utc_now())
      completed = job_fixture(state: "completed", completed_at: DateTime.utc_now())

      {:ok, view, _html} = live(conn, ~p"/jobs")

      assert has_element?(view, "#job-#{executing.id} button", "Cancel")
      refute has_element?(view, "#job-#{executing.id} button", "Retry")
      refute has_element?(view, "#job-#{executing.id} button", "Delete")

      assert has_element?(view, "#job-#{scheduled.id} button", "Run now")
      assert has_element?(view, "#job-#{scheduled.id} button", "Cancel")

      assert has_element?(view, "#job-#{completed.id} button", "Retry")
      assert has_element?(view, "#job-#{completed.id} button", "Delete")
      refute has_element?(view, "#job-#{completed.id} button", "Cancel")
    end

    test "retries a job", %{conn: conn} do
      job = job_fixture(state: "discarded", attempt: 20, discarded_at: DateTime.utc_now())

      {:ok, view, _html} = live(conn, ~p"/jobs")

      assert view |> element("#job-#{job.id} button", "Retry") |> render_click() =~
               "Job ##{job.id} queued to run"

      assert %{state: "available"} = Jobs.get_job(job.id)
    end

    test "cancels a job", %{conn: conn} do
      job = job_fixture()

      {:ok, view, _html} = live(conn, ~p"/jobs")

      assert view |> element("#job-#{job.id} button", "Cancel") |> render_click() =~
               "Job ##{job.id} cancelled"

      assert %{state: "cancelled"} = Jobs.get_job(job.id)
    end

    test "deletes a job", %{conn: conn} do
      job = job_fixture(state: "completed", completed_at: DateTime.utc_now())

      {:ok, view, _html} = live(conn, ~p"/jobs")

      assert view |> element("#job-#{job.id} button", "Delete") |> render_click() =~
               "Job ##{job.id} deleted"

      refute has_element?(view, "#job-#{job.id}")
      assert Jobs.get_job(job.id) == nil
    end

    test "reports actions that are no longer allowed", %{conn: conn} do
      job = job_fixture()

      {:ok, view, _html} = live(conn, ~p"/jobs")
      mark_executing(job)

      assert view |> element("#job-#{job.id} button", "Delete") |> render_click() =~
               "Job ##{job.id} can&#39;t be deleted while executing"

      assert Jobs.get_job(job.id)
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
          state: "retryable",
          attempt: 1,
          args: %{"to" => "david@example.com"},
          meta: %{"source" => "signup"},
          tags: ["email"],
          errors: [
            %{"attempt" => 1, "at" => "2024-09-18T12:00:00Z", "error" => "** (RuntimeError) boom"}
          ]
        )

      {:ok, view, html} = live(conn, ~p"/jobs/#{job.id}")

      assert html =~ "Job ##{job.id}"
      assert html =~ "MyApp.EmailWorker"
      assert html =~ "retryable"
      assert html =~ "email"
      assert has_element?(view, "#job-args", "david@example.com")
      assert has_element?(view, "#job-meta", "signup")
      assert has_element?(view, "#job-errors", "(RuntimeError) boom")
    end

    test "responds with not found for a missing job", %{conn: conn} do
      assert_error_sent 404, fn -> live(conn, ~p"/jobs/0") end
    end

    test "cancels the job", %{conn: conn} do
      job = job_fixture()

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job.id}")

      html = view |> element("button", "Cancel") |> render_click()

      assert html =~ "Job ##{job.id} cancelled"
      refute has_element?(view, "button", "Cancel")
      assert %{state: "cancelled"} = Jobs.get_job(job.id)
    end

    test "deletes the job and returns to the index", %{conn: conn} do
      job = job_fixture(state: "completed", completed_at: DateTime.utc_now())

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job.id}")

      {:ok, _index, html} =
        view
        |> element("button", "Delete")
        |> render_click()
        |> follow_redirect(conn, ~p"/jobs")

      assert html =~ "Job ##{job.id} deleted"
      assert Jobs.get_job(job.id) == nil
    end

    test "returns to the index when the job disappears", %{conn: conn} do
      job = job_fixture()

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job.id}")

      Repo.delete!(job)
      send(view.pid, :refresh)

      flash = assert_redirect(view, ~p"/jobs")
      assert flash["error"] == "Job ##{job.id} no longer exists"
    end
  end
end
