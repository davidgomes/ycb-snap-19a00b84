defmodule PlugRailsCookieSessionStoreTest do
  use ExUnit.Case, async: true
  use Plug.Test

  @default_opts [
    store: PlugRailsCookieSessionStore,
    key: "foobar",
    encryption_salt: "encrypted cookie salt",
    signing_salt: "signing salt"
  ]

  @secret String.duplicate("abcdef0123456789", 8)

  defp sign_conn(conn, secret \\ @secret) do
    put_in(conn.secret_key_base, secret)
    |> Plug.Session.call(Plug.Session.init(@default_opts))
    |> fetch_session
  end

  test "session cookies are signed and encrypted" do
    conn =
      conn(:get, "/")
      |> sign_conn()
      |> put_session("foo", "bar")
      |> send_resp(200, "")

    cookie = conn.resp_cookies["foobar"].value
    refute cookie =~ "bar"

    conn =
      conn(:get, "/")
      |> put_req_cookie("foobar", cookie)
      |> sign_conn()

    assert get_session(conn, "foo") == "bar"
  end

  test "requires a secret_key_base of at least 64 bytes" do
    assert_raise ArgumentError, fn ->
      conn(:get, "/")
      |> sign_conn("short secret")
      |> put_session("foo", "bar")
      |> send_resp(200, "")
    end
  end

  test "requires a signing salt" do
    assert_raise ArgumentError, ~r/:signing_salt/, fn ->
      PlugRailsCookieSessionStore.init(encryption_salt: "salt")
    end
  end

  test "requires an encryption salt when encryption is enabled" do
    assert_raise ArgumentError, ~r/:encryption_salt/, fn ->
      PlugRailsCookieSessionStore.init(signing_salt: "salt")
    end
  end
end
