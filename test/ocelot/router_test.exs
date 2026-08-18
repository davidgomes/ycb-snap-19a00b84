defmodule Ocelot.RouterTest do
  use ExUnit.Case, async: true
  use Plug.Test

  @opts Ocelot.Router.init([])

  test "GET / renders the dashboard page" do
    conn = conn(:get, "/") |> Ocelot.Router.call(@opts)

    assert conn.state == :sent
    assert conn.status == 200
    assert {"content-type", "text/html; charset=utf-8"} in conn.resp_headers
    assert conn.resp_body =~ "Ocelot"
    assert conn.resp_body =~ "Oban Web Lite Dashboard"
  end

  test "unknown routes return 404" do
    conn = conn(:get, "/missing") |> Ocelot.Router.call(@opts)

    assert conn.state == :sent
    assert conn.status == 404
  end
end
