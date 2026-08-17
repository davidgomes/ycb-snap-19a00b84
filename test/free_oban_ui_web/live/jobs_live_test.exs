defmodule FreeObanUiWeb.JobsLiveTest do
  use FreeObanUiWeb.ConnCase

  import Phoenix.LiveViewTest

  alias FreeObanUi.Workers.ExampleWorker

  test "lists jobs", %{conn: conn} do
    {:ok, job} = ExampleWorker.new(%{"email" => "user@example.com"}) |> Oban.insert()

    {:ok, view, html} = live(conn, ~p"/")

    assert html =~ "Oban Jobs"
    assert has_element?(view, "#job-#{job.id}")
    assert html =~ "FreeObanUi.Workers.ExampleWorker"
    assert html =~ "available"
  end

  test "filters jobs by state", %{conn: conn} do
    {:ok, available} = ExampleWorker.new(%{"kind" => "available"}) |> Oban.insert()

    {:ok, cancelled} =
      ExampleWorker.new(%{"kind" => "cancelled"})
      |> Oban.insert()

    :ok = Oban.cancel_job(cancelled)

    {:ok, view, _html} = live(conn, ~p"/?state=cancelled")

    assert has_element?(view, "#job-#{cancelled.id}")
    refute has_element?(view, "#job-#{available.id}")
  end

  test "shows an empty state when there are no jobs", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "No jobs found."
  end
end
