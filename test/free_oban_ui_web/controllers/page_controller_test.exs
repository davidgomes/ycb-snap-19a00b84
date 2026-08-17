defmodule FreeObanUiWeb.PageControllerTest do
  use FreeObanUiWeb.ConnCase

  test "GET / redirects into the jobs live view", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Oban Jobs"
  end
end
