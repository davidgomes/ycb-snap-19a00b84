defmodule FreeObanUiWeb.ObanLiveTest do
  use FreeObanUiWeb.ConnCase

  import Phoenix.LiveViewTest
  alias FreeObanUi.Jobs
  alias FreeObanUi.Workers.ExampleWorker

  test "renders Oban UI dashboard and allows filtering and job operations", %{conn: conn} do
    {:ok, job} =
      %{task: "liveview_test"}
      |> ExampleWorker.new(queue: :default)
      |> Oban.insert()

    {:ok, view, html} = live(conn, ~p"/oban")
    assert html =~ "Oban Dashboard"
    assert html =~ "##{job.id}"
    assert html =~ "available"

    # Enqueue a sample job via UI
    assert view
           |> element("button", "+ Enqueue Sample Job")
           |> render_click() =~ "Sample success job enqueued"

    # Enqueue failing job via UI
    assert view
           |> element("button", "+ Enqueue Failing Job")
           |> render_click() =~ "Sample failure job enqueued"

    # Enqueue scheduled job via UI
    assert view
           |> element("button", "+ Enqueue Scheduled Job")
           |> render_click() =~ "Sample scheduled job enqueued"

    # Filter by state
    assert view
           |> element("button[phx-value-state='available']")
           |> render_click() =~ "available"

    # Filter by queue and search
    rendered =
      view
      |> form("form[phx-change='filter']", %{"queue" => "default", "search" => "ExampleWorker"})
      |> render_change()

    assert rendered =~ "ExampleWorker"

    # Sort columns
    assert view
           |> element("th[phx-click='sort'][phx-value-by='id']")
           |> render_click() =~ "ID"

    # Open job detail modal
    assert view
           |> element("button", "##{job.id}")
           |> render_click() =~ "Arguments (Args)"

    # Retry job from table/modal
    Jobs.cancel_job(job.id)

    assert view
           |> element("button", "##{job.id}")
           |> render_click()

    assert view
           |> element("button", "Retry Job")
           |> render_click() =~ "Job ##{job.id} scheduled for retry."

    # Cancel job from modal
    assert view
           |> element("button", "Cancel Job")
           |> render_click() =~ "Job ##{job.id} cancelled."

    # Close modal
    assert view
           |> element("button", "Close")
           |> render_click()

    refute render(view) =~ "Arguments (Args)"

    # Bulk actions
    assert view
           |> element("button", "Retry All")
           |> render_click() =~ "Retried"

    assert view
           |> element("button", "Cancel All")
           |> render_click() =~ "Cancelled"

    # Select "all" state to see all jobs again
    assert view
           |> element("button[phx-value-state='all']")
           |> render_click()

    # Delete job from modal
    assert view
           |> element("button", "##{job.id}")
           |> render_click()

    assert view
           |> element("button", "Delete Job")
           |> render_click() =~ "Job ##{job.id} deleted."
  end

  test "handles params for direct linking and pagination", %{conn: conn} do
    {:ok, job} =
      %{param_task: "direct_link"}
      |> ExampleWorker.new(queue: :events)
      |> Oban.insert()

    {:ok, view, html} = live(conn, ~p"/oban?job_id=#{job.id}&queue=events&state=available")
    assert html =~ "Job ##{job.id}"
    assert html =~ "Arguments (Args)"

    # Periodic tick info event
    send(view.pid, :tick)
    assert render(view) =~ "Oban Dashboard"
  end
end
