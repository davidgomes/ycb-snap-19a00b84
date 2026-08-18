defmodule Ocelot.RouterTest do
  use ExUnit.Case, async: true

  import Plug.Test
  import Plug.Conn

  @opts Ocelot.Router.init([])

  test "GET / returns the dashboard UI" do
    conn = conn(:get, "/") |> Ocelot.Router.call(@opts)

    assert conn.state == :sent
    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["text/html; charset=utf-8"]
    assert conn.resp_body =~ "Ocelot"
  end

  test "unknown routes return a 404" do
    conn = conn(:get, "/does-not-exist") |> Ocelot.Router.call(@opts)

    assert conn.status == 404
  end
end
