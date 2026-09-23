defmodule FreeObanUiWeb.ObanLiveTest do
  use FreeObanUiWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias FreeObanUi.Repo

  test "lists jobs and cancels one from the detail page", %{conn: conn} do
    job =
      %{"hello" => "world"}
      |> Oban.Job.new(worker: "FreeObanUi.Workers.Example", queue: "default", schedule_in: 3600)
      |> Repo.insert!()

    {:ok, _index_live, html} = live(conn, ~p"/oban")

    assert html =~ "Oban Jobs"
    assert html =~ "scheduled"
    assert html =~ "FreeObanUi.Workers.Example"
    assert html =~ "default"

    {:ok, show_live, show_html} = live(conn, ~p"/oban/#{job.id}")

    assert show_html =~ "Job ##{job.id}"
    assert show_html =~ "FreeObanUi.Workers.Example"
    assert show_html =~ "hello"

    show_html = render_click(show_live, "execute_action", %{"action" => "cancel"})

    assert show_html =~ "cancelled"
    assert Repo.get!(Oban.Job, job.id).state == "cancelled"
  end

  test "filters the job list by state", %{conn: conn} do
    %{"n" => 1}
    |> Oban.Job.new(worker: "FreeObanUi.Workers.Scheduled", schedule_in: 60)
    |> Repo.insert!()

    %{n: 2}
    |> Oban.Job.new(worker: "FreeObanUi.Workers.Available")
    |> Repo.insert!()

    {:ok, _live, html} = live(conn, ~p"/oban?state=scheduled")

    assert html =~ "FreeObanUi.Workers.Scheduled"
    refute html =~ "FreeObanUi.Workers.Available"
  end
end
