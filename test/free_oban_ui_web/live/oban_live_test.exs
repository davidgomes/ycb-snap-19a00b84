defmodule FreeObanUiWeb.ObanLiveTest do
  use FreeObanUiWeb.ConnCase

  import Phoenix.LiveViewTest

  alias FreeObanUi.Repo

  defp insert_job(worker, attrs) do
    attrs = Map.new(attrs)

    %{hello: "world"}
    |> Oban.Job.new(worker: worker, queue: attrs[:queue] || "default")
    |> Ecto.Changeset.put_change(:state, attrs[:state] || "scheduled")
    |> Repo.insert!()
  end

  test "lists jobs and shows a job", %{conn: conn} do
    job = insert_job("FreeObanUi.ExampleWorker", state: "scheduled", queue: "default")

    {:ok, _view, html} = live(conn, ~p"/oban")

    assert html =~ "Oban Jobs"
    assert html =~ "FreeObanUi.ExampleWorker"
    assert html =~ "scheduled"

    {:ok, view, html} = live(conn, ~p"/oban/#{job.id}")

    assert html =~ "Job ##{job.id}"
    assert html =~ "FreeObanUi.ExampleWorker"
    assert html =~ "hello"

    view |> element("button", "Delete") |> render_click()
    refute Repo.get(Oban.Job, job.id)
  end

  test "filters by state and queue", %{conn: conn} do
    insert_job("Keep.Me", queue: "default", state: "completed")
    insert_job("Drop.Me", queue: "mailers", state: "discarded")

    {:ok, _view, html} = live(conn, ~p"/oban?state=completed&queue=default")

    assert html =~ "Keep.Me"
    refute html =~ "Drop.Me"
  end
end
