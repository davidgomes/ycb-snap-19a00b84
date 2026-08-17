defmodule FreeObanUiWeb.ObanLive.IndexTest do
  use FreeObanUiWeb.ConnCase

  import Phoenix.LiveViewTest

  test "lists jobs", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/oban")

    assert html =~ "Oban Jobs"
    assert html =~ "States"
    assert html =~ "Queues"
  end

  test "filters jobs by state", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/oban?state=scheduled")

    assert html =~ "scheduled"
    assert html =~ "Clear"
  end
end
