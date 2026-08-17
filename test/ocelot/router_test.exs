defmodule Ocelot.RouterTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Ocelot.Router

  @opts Router.init([])

  test "GET / returns the dashboard HTML" do
    conn = conn(:get, "/") |> Router.call(@opts)

    assert conn.state == :sent
    assert conn.status == 200
    assert get_resp_content_type(conn) == "text/html"
    assert conn.resp_body =~ "Ocelot"
  end

  test "unknown routes return 404" do
    conn = conn(:get, "/missing") |> Router.call(@opts)

    assert conn.state == :sent
    assert conn.status == 404
  end

  defp get_resp_content_type(conn) do
    conn
    |> Plug.Conn.get_resp_header("content-type")
    |> List.first()
    |> String.split(";")
    |> List.first()
  end
end
