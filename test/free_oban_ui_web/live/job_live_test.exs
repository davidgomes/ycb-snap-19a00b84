defmodule FreeObanUiWeb.JobLiveTest do
  use FreeObanUiWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import FreeObanUi.JobsFixtures

  alias FreeObanUi.Jobs

  describe "Index" do
    test "lists jobs with state counts", %{conn: conn} do
      job = job_fixture(worker: "MyApp.Mailer", args: %{"email" => "a@example.com"})
      job_fixture(state: "completed")

      {:ok, view, html} = live(conn, ~p"/jobs")

      assert html =~ "MyApp.Mailer"
      assert html =~ "a@example.com"
      assert has_element?(view, "#jobs-#{job.id}")
      assert has_element?(view, ~s|a[href="/jobs"]|, "2")
      assert has_element?(view, ~s|a[href="/jobs?state=completed"]|, "1")
    end

    test "filters jobs by state", %{conn: conn} do
      available = job_fixture(state: "available")
      completed = job_fixture(state: "completed")

      {:ok, view, _html} = live(conn, ~p"/jobs")

      view |> element(~s|a[href="/jobs?state=completed"]|) |> render_click()

      assert_patch(view, ~p"/jobs?state=completed")
      assert has_element?(view, "#jobs-#{completed.id}")
      refute has_element?(view, "#jobs-#{available.id}")
    end

    test "ignores unknown states", %{conn: conn} do
      job = job_fixture()

      {:ok, view, _html} = live(conn, ~p"/jobs?state=bogus")

      assert has_element?(view, "#jobs-#{job.id}")
    end

    test "shows an empty message without jobs", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/jobs")

      assert has_element?(view, "#no-jobs")
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
      job =
        job_fixture(
          worker: "MyApp.Mailer",
          args: %{"email" => "a@example.com"},
          tags: ["mail"],
          state: "retryable",
          attempt: 1,
          errors: [%{"attempt" => 1, "at" => "2024-09-01T00:00:00Z", "error" => "boom"}]
        )

      {:ok, view, html} = live(conn, ~p"/jobs/#{job}")

      assert html =~ "MyApp.Mailer"
      assert html =~ "mail"
      assert html =~ "boom"
      assert view |> element("#job-args") |> render() =~ "a@example.com"
    end

    test "retries a job", %{conn: conn} do
      job = job_fixture(state: "discarded")

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job}")

      assert view |> element("#retry-job") |> render_click() =~ "Job retried"
      assert %{state: "available"} = Jobs.get_job!(job.id)
      refute has_element?(view, "#retry-job")
    end

    test "cancels a job", %{conn: conn} do
      job = job_fixture(state: "scheduled")

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job}")

      assert view |> element("#cancel-job") |> render_click() =~ "Job cancelled"
      assert %{state: "cancelled"} = Jobs.get_job!(job.id)
      refute has_element?(view, "#cancel-job")
    end

    test "deletes a job", %{conn: conn} do
      job = job_fixture(state: "completed")

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job}")

      assert {:ok, _index, html} =
               view
               |> element("#delete-job")
               |> render_click()
               |> follow_redirect(conn, ~p"/jobs")

      assert html =~ "Job deleted"
      refute Jobs.get_job(job.id)
    end

    test "hides actions that don't apply to executing jobs", %{conn: conn} do
      job = job_fixture(state: "executing")

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job}")

      refute has_element?(view, "#retry-job")
      refute has_element?(view, "#delete-job")
      assert has_element?(view, "#cancel-job")
    end

    test "redirects when the job disappears", %{conn: conn} do
      job = job_fixture()

      {:ok, view, _html} = live(conn, ~p"/jobs/#{job}")

      FreeObanUi.Repo.delete!(job)
      send(view.pid, :refresh)

      assert_redirect(view, ~p"/jobs")
    end

    test "raises for unknown jobs", %{conn: conn} do
      assert_raise Ecto.NoResultsError, fn -> live(conn, ~p"/jobs/0") end
    end
  end
end
