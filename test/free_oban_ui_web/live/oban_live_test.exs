defmodule FreeObanUiWeb.ObanLiveTest do
  use FreeObanUiWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias FreeObanUi.Repo

  test "lists jobs, filters by state, and cancels or deletes a job", %{conn: conn} do
    now = DateTime.utc_now()

    job =
      Repo.insert!(%Oban.Job{
        worker: "FreeObanUi.Noop",
        args: %{"hello" => "world"},
        state: "scheduled",
        queue: "default",
        inserted_at: now,
        scheduled_at: now
      })

    {:ok, view, html} = live(conn, ~p"/oban")

    assert html =~ "Oban Jobs"
    assert html =~ "scheduled"
    assert html =~ "FreeObanUi.Noop"
    assert html =~ "default"

    html = view |> element("a", "scheduled") |> render_click()
    assert html =~ "FreeObanUi.Noop"

    {:ok, view, html} = live(conn, ~p"/oban/#{job.id}")
    assert html =~ "Job ##{job.id}"
    assert html =~ "FreeObanUi.Noop"
    assert html =~ "hello"
    assert html =~ "Run"
    assert html =~ "Cancel"

    view |> element("button", "Cancel") |> render_click()
    assert Repo.get!(Oban.Job, job.id).state == "cancelled"

    view |> element("button", "Delete") |> render_click()
    assert Repo.get(Oban.Job, job.id) == nil
  end
end
