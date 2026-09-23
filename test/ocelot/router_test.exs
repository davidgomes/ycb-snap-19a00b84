defmodule Ocelot.RouterTest do
  use ExUnit.Case, async: true

  import Plug.Test

  defmodule HostRouter do
    use Plug.Router

    plug :match
    plug :dispatch

    forward "/oban", to: Ocelot.Router, init_opts: [oban: MyApp.Oban]
  end

  defp call(path), do: HostRouter.call(conn(:get, path), HostRouter.init([]))

  test "unknown pages render a 404 linking back to the mount path" do
    conn = call("/oban/unknown")

    assert conn.status == 404
    assert ["text/html" <> _] = Plug.Conn.get_resp_header(conn, "content-type")
    assert conn.resp_body =~ "This page doesn&#39;t exist."
    assert conn.resp_body =~ ~s(<a href="/oban/">← Back to jobs</a>)
    assert conn.resp_body =~ "MyApp.Oban"
  end

  test "non-numeric job ids render a 404" do
    conn = call("/oban/jobs/%3Coops%3E")

    assert conn.status == 404
    assert conn.resp_body =~ "Job &lt;oops&gt; doesn&#39;t exist."
  end

  test "init/1 validates options" do
    assert Ocelot.Router.init([]) == [oban: Oban]
    assert_raise ArgumentError, fn -> Ocelot.Router.init(repo: MyApp.Repo) end
  end
end
