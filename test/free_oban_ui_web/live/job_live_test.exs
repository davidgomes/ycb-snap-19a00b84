defmodule FreeObanUiWeb.JobLiveTest do
  use FreeObanUiWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias FreeObanUi.Workers.Noop

  test "lists inserted jobs and cancels one", %{conn: conn} do
    {:ok, job} = Oban.insert(Noop.new(%{"hello" => "world"}))

    {:ok, view, html} = live(conn, ~p"/jobs")

    assert html =~ "Oban jobs"
    assert html =~ "Noop"
    assert has_element?(view, "#jobs")

    view
    |> element("button[phx-click=cancel][phx-value-id='#{job.id}']")
    |> render_click()

    assert render(view) =~ "cancelled"
  end

  test "filters by state and opens a job", %{conn: conn} do
    {:ok, job} = Oban.insert(Noop.new(%{"n" => 1}))

    {:ok, view, _html} = live(conn, ~p"/jobs?state=available")
    assert render(view) =~ to_string(job.id)

    {:ok, _view, html} = live(conn, ~p"/jobs/#{job.id}")
    assert html =~ "FreeObanUi.Workers.Noop"
    assert html =~ "available"
    assert html =~ "Args"
  end
end
