defmodule FreeObanUiWeb.JobLiveTest do
  use FreeObanUiWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  test "lists a job and opens its detail", %{conn: conn} do
    {:ok, job} =
      %{"hello" => "world"}
      |> Oban.Job.new(worker: "FreeObanUi.Workers.Example", queue: "default")
      |> Oban.insert()

    {:ok, index, html} = live(conn, ~p"/jobs")
    assert html =~ "FreeObanUi.Workers.Example"
    assert html =~ "default"

    {:ok, show, html} = index |> element("#job-#{job.id} a") |> render_click() |> follow_redirect(conn)
    assert html =~ "hello"
    assert html =~ "world"
    assert has_element?(show, "button", "Cancel")
  end
end
