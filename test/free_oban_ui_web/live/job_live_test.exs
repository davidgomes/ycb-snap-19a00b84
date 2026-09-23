defmodule FreeObanUiWeb.JobLiveTest do
  use FreeObanUiWeb.ConnCase

  import Phoenix.LiveViewTest

  alias FreeObanUi.Workers.Example

  test "lists inserted jobs and cancels one", %{conn: conn} do
    {:ok, job} = Example.new(%{"hello" => "world"}) |> Oban.insert()

    {:ok, view, html} = live(conn, ~p"/jobs")

    assert html =~ "Oban jobs"
    assert html =~ "FreeObanUi.Workers.Example"
    assert has_element?(view, "#job-#{job.id}")

    view |> element("#job-#{job.id} button", "Cancel") |> render_click()

    assert has_element?(view, "#job-#{job.id}", "cancelled")
  end

  test "filters by state", %{conn: conn} do
    {:ok, _job} = Example.new(%{"n" => 1}) |> Oban.insert()

    {:ok, view, _html} = live(conn, ~p"/jobs?state=completed")

    refute has_element?(view, "td", "FreeObanUi.Workers.Example")
  end

  test "shows job args", %{conn: conn} do
    {:ok, job} = Example.new(%{"hello" => "world"}) |> Oban.insert()

    {:ok, _view, html} = live(conn, ~p"/jobs/#{job.id}")

    assert html =~ "Job ##{job.id}"
    assert html =~ "hello"
    assert html =~ "world"
  end
end
