defmodule FreeObanUiWeb.JobLiveTest do
  use FreeObanUiWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias FreeObanUi.Workers.PingWorker

  setup do
    {:ok, job} =
      %{message: "hello"}
      |> PingWorker.new(queue: "default")
      |> Oban.insert()

    %{job: job}
  end

  test "lists jobs and enqueues a sample", %{conn: conn, job: job} do
    {:ok, view, html} = live(conn, ~p"/jobs")

    assert html =~ "Oban jobs"
    assert html =~ "FreeObanUi.Workers.PingWorker"
    assert has_element?(view, "#jobs-#{job.id}")

    view
    |> form("#enqueue-form", %{message: "from the ui"})
    |> render_submit()

    assert render(view) =~ "Enqueued job"
  end

  test "filters by queue", %{conn: conn, job: job} do
    {:ok, other} =
      %{message: "other"}
      |> PingWorker.new(queue: "mail")
      |> Oban.insert()

    {:ok, view, _html} = live(conn, ~p"/jobs")

    view
    |> form("#job-filters", %{queue: "mail", state: "", worker: ""})
    |> render_change()

    refute has_element?(view, "#jobs-#{job.id}")
    assert has_element?(view, "#jobs-#{other.id}")
  end

  test "shows, cancels, and retries a job", %{conn: conn, job: job} do
    {:ok, view, html} = live(conn, ~p"/jobs/#{job.id}")

    assert html =~ "hello"
    assert html =~ "available"

    view |> element("#cancel-job") |> render_click()
    assert render(view) =~ "cancelled"

    view |> element("#retry-job") |> render_click()
    assert render(view) =~ "available"
  end

  test "redirects when the job does not exist", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: "/jobs"}}} = live(conn, ~p"/jobs/999999")
  end
end
