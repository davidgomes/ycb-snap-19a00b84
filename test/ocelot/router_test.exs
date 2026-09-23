defmodule Ocelot.RouterTest do
  use ExUnit.Case, async: true

  import Plug.Test

  defmodule MountedRouter do
    use Plug.Router

    plug(:match)
    plug(:dispatch)

    forward("/oban", to: Ocelot.Router)
  end

  test "responds with 404 for unknown paths" do
    conn = Ocelot.Router.call(conn(:get, "/unknown"), Ocelot.Router.init([]))

    assert conn.status == 404
    assert conn.resp_body =~ "Not found"
  end

  test "responds with 404 for non numeric job ids" do
    conn = Ocelot.Router.call(conn(:get, "/jobs/abc"), Ocelot.Router.init([]))

    assert conn.status == 404
  end

  test "links relative to the mount path" do
    conn = MountedRouter.call(conn(:get, "/oban/unknown"), MountedRouter.init([]))

    assert conn.status == 404
    assert conn.resp_body =~ ~s(<a href="/oban/">Ocelot</a>)
  end
end
