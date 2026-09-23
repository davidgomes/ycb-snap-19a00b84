defmodule FreeObanUiWeb.JobLiveTest do
  use FreeObanUiWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias FreeObanUi.{Jobs, Repo}

  defp insert_job(attrs \\ %{}) do
    %{"user_id" => 42}
    |> Oban.Job.new(worker: "MyApp.EmailWorker", queue: "mailers")
    |> Ecto.Changeset.change(attrs)
    |> Repo.insert!()
  end

  describe "Index" do
    test "lists jobs with state counts", %{conn: conn} do
      job = insert_job()
      insert_job(%{state: "completed"})

      {:ok, view, html} = live(conn, ~p"/jobs")

      assert html =~ "EmailWorker"
      assert has_element?(view, "#job-#{job.id}")
      assert has_element?(view, "#filter-available", "available (1)")
      assert has_element?(view, "#filter-completed", "completed (1)")
    end

    test "filters by state", %{conn: conn} do
      available = insert_job()
      completed = insert_job(%{state: "completed"})

      {:ok, view, _html} = live(conn, ~p"/jobs")
      view |> element("#filter-completed") |> render_click()

      assert_patch(view, ~p"/jobs?state=completed")
      assert has_element?(view, "#job-#{completed.id}")
      refute has_element?(view, "#job-#{available.id}")
    end

    test "shows an empty state", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/jobs")
      assert has_element?(view, "#no-jobs")
    end

    test "retries, cancels and deletes jobs", %{conn: conn} do
      job = insert_job(%{state: "discarded"})
      {:ok, view, _html} = live(conn, ~p"/jobs")

      view |> element("#job-#{job.id} a", "Retry") |> render_click()
      assert Jobs.get_job(job.id).state == "available"

      view |> element("#job-#{job.id} a", "Cancel") |> render_click()
      assert Jobs.get_job(job.id).state == "cancelled"

      view |> element("#job-#{job.id} a", "Delete") |> render_click()
      refute Jobs.get_job(job.id)
      refute has_element?(view, "#job-#{job.id}")
    end
  end

  describe "Show" do
    test "displays job details", %{conn: conn} do
      job = insert_job(%{errors: [%{"attempt" => 1, "at" => "now", "error" => "boom"}]})

      {:ok, view, html} = live(conn, ~p"/jobs/#{job.id}")

      assert html =~ "MyApp.EmailWorker"
      assert html =~ "mailers"
      assert html =~ "boom"
      assert view |> element("#job-args") |> render() =~ "user_id"
    end

    test "cancels and deletes the job", %{conn: conn} do
      job = insert_job()
      {:ok, view, _html} = live(conn, ~p"/jobs/#{job.id}")

      view |> element("#cancel-job") |> render_click()
      assert Jobs.get_job(job.id).state == "cancelled"
      refute has_element?(view, "#cancel-job")

      view |> element("#delete-job") |> render_click()
      assert_redirect(view, ~p"/jobs")
      refute Jobs.get_job(job.id)
    end

    test "redirects when the job does not exist", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/jobs"}}} = live(conn, ~p"/jobs/0")
    end
  end
end
