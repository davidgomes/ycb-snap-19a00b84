defmodule PlugRailsCookieSessionStoreTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn

  alias PlugRailsCookieSessionStore, as: CookieStore

  @default_opts [
    store: CookieStore,
    key: "foobar",
    encryption_salt: "encrypted cookie salt",
    signing_salt: "signing salt"
  ]

  @secret String.duplicate("abcdef0123456789", 8)
  @signing_opts Plug.Session.init(Keyword.put(@default_opts, :encrypt, false))
  @signing_without_salt_opts Plug.Session.init(Keyword.put(@default_opts, :signing_with_salt, false))
  @encrypted_opts Plug.Session.init(@default_opts)

  defmodule CustomSerializer do
    def encode(%{"foo" => "bar"}), do: {:ok, "encoded session"}
    def encode(%{foo: :bar}), do: {:ok, "another encoded session"}
    def encode(%{}), do: {:ok, ""}
    def encode(_), do: :error

    def decode("encoded session"), do: {:ok, %{"foo" => "bar"}}
    def decode("another encoded session"), do: {:ok, %{foo: :bar}}
    def decode(nil), do: {:ok, nil}
    def decode(_), do: :error
  end
  @custom_serializer_opts Plug.Session.init(Keyword.put(@default_opts, :serializer, CustomSerializer))

  defp sign_conn(conn, secret \\ @secret) do
    put_in(conn.secret_key_base, secret)
    |> Plug.Session.call(@signing_opts)
    |> fetch_session
  end

  defp encrypt_conn(conn) do
    put_in(conn.secret_key_base, @secret)
    |> Plug.Session.call(@encrypted_opts)
    |> fetch_session
  end

  defp custom_serialize_conn(conn) do
    put_in(conn.secret_key_base, @secret)
    |> Plug.Session.call(@custom_serializer_opts)
    |> fetch_session
  end

  test "requires signing_salt option to be defined" do
    assert_raise ArgumentError, ~r/expects :signing_salt as option/, fn ->
      Plug.Session.init(Keyword.delete(@default_opts, :signing_salt))
    end
  end

  test "requires encrypted_salt option to be defined" do
    assert_raise ArgumentError, ~r/expects :encryption_salt as option/, fn ->
      Plug.Session.init(Keyword.delete(@default_opts, :encryption_salt))
    end
  end

  test "requires the secret to be at least 64 bytes" do
    assert_raise ArgumentError, ~r/to be at least 64 bytes/, fn ->
      conn(:get, "/")
      |> sign_conn("abcdef")
      |> put_session(:foo, "bar")
      |> send_resp(200, "OK")
    end
  end

  test "defaults key generator opts" do
    key_generator_opts = CookieStore.init(@default_opts).key_opts
    assert key_generator_opts[:iterations] == 1000
    assert key_generator_opts[:length] == 32
    assert key_generator_opts[:digest] == :sha256
  end

  test "uses specified key generator opts" do
    opts = @default_opts
            |> Keyword.put(:key_iterations, 2000)
            |> Keyword.put(:key_length, 64)
            |> Keyword.put(:key_digest, :sha)
    key_generator_opts = CookieStore.init(opts).key_opts
    assert key_generator_opts[:iterations] == 2000
    assert key_generator_opts[:length] == 64
    assert key_generator_opts[:digest] == :sha
  end

  test "requires serializer option to be an atom" do
    assert_raise ArgumentError, ~r/expects :serializer option to be a module/, fn ->
      Plug.Session.init(Keyword.put(@default_opts, :serializer, "CustomSerializer"))
    end
  end

  test "uses :external_term_format cookie serializer by default" do
    assert Plug.Session.init(@default_opts).store_config.serializer == :external_term_format
  end

  test "uses custom cookie serializer" do
    assert @custom_serializer_opts.store_config.serializer == CustomSerializer
  end

  ## Signed

  test "session cookies are signed" do
    conn = %{secret_key_base: @secret}
    cookie = CookieStore.put(conn, nil, %{foo: :bar}, @signing_opts.store_config)
    assert is_binary(cookie)
    assert CookieStore.get(conn, cookie, @signing_opts.store_config) == {nil, %{foo: :bar}}
  end

  test "session cookies are signed without salt" do
    conn = %{secret_key_base: @secret}
    cookie = CookieStore.put(conn, nil, %{foo: :bar}, @signing_without_salt_opts.store_config)
    assert is_binary(cookie)
    assert CookieStore.get(conn, cookie, @signing_without_salt_opts.store_config) == {nil, %{foo: :bar}}
  end


  test "gets and sets signed session cookie" do
    conn = conn(:get, "/")
           |> sign_conn()
           |> put_session(:foo, "bar")
           |> send_resp(200, "")
    assert conn(:get, "/")
           |> recycle_cookies(conn)
           |> sign_conn()
           |> get_session(:foo) == "bar"
  end

  test "deletes signed session cookie" do
    conn = conn(:get, "/")
           |> sign_conn()
           |> put_session(:foo, :bar)
           |> configure_session(drop: true)
           |> send_resp(200, "")
    assert conn(:get, "/")
           |> recycle_cookies(conn)
           |> sign_conn()
           |> get_session(:foo) == nil
  end

  ## Encrypted

  test "session cookies are encrypted" do
    conn = %{secret_key_base: @secret}
    cookie = CookieStore.put(conn, nil, %{foo: :bar}, @encrypted_opts.store_config)
    assert is_binary(cookie)
    assert CookieStore.get(conn, cookie, @encrypted_opts.store_config) == {nil, %{foo: :bar}}
  end

  test "gets and sets encrypted session cookie" do
    conn = conn(:get, "/")
           |> encrypt_conn()
           |> put_session(:foo, "bar")
           |> send_resp(200, "")
    assert conn(:get, "/")
           |> recycle_cookies(conn)
           |> encrypt_conn()
           |> get_session(:foo) == "bar"
  end

  test "deletes encrypted session cookie" do
    conn = conn(:get, "/")
           |> encrypt_conn()
           |> put_session(:foo, :bar)
           |> configure_session(drop: true)
           |> send_resp(200, "")
    assert conn(:get, "/")
           |> recycle_cookies(conn)
           |> encrypt_conn()
           |> get_session(:foo) == nil
  end

  ## Custom Serializer

  test "session cookies are serialized by the custom serializer" do
    conn = %{secret_key_base: @secret}
    cookie = CookieStore.put(conn, nil, %{foo: :bar}, @custom_serializer_opts.store_config)
    assert is_binary(cookie)
    assert CookieStore.get(conn, cookie, @custom_serializer_opts.store_config) == {nil, %{foo: :bar}}
  end

  test "gets and sets custom serialized session cookie" do
    conn = conn(:get, "/")
           |> custom_serialize_conn()
           |> put_session(:foo, "bar")
           |> send_resp(200, "")
    assert conn(:get, "/")
           |> recycle_cookies(conn)
           |> custom_serialize_conn()
           |> get_session(:foo) == "bar"
  end

  test "deletes custom serialized session cookie" do
    conn = conn(:get, "/")
           |> custom_serialize_conn()
           |> put_session(:foo, :bar)
           |> configure_session(drop: true)
           |> send_resp(200, "")
    assert conn(:get, "/")
           |> recycle_cookies(conn)
           |> custom_serialize_conn()
           |> get_session(:foo) == nil
  end

  ## Rails 4 and Rails 5

  defmodule PassthroughSerializer do
    def encode(binary), do: {:ok, binary}
    def decode(binary), do: {:ok, binary}
  end

  # Rails derives cookie keys with ActiveSupport::KeyGenerator (PBKDF2-HMAC-SHA1,
  # 1000 iterations, 64 byte keys) using these default salts.
  @rails_opts CookieStore.init(
    encryption_salt: "encrypted cookie",
    signing_salt: "signed encrypted cookie",
    key_iterations: 1000,
    key_length: 64,
    key_digest: :sha,
    serializer: PassthroughSerializer
  )

  @rails_session ~s({"session_id":"d1ccef272dab52cc52f9a3a1eaad328f","_csrf_token":"SzOx1XoIY2ewP/F/v45TIr2Ay+BNtiouhU5Xj2zOLDg=","user_id":42,"foo":"bar"})

  # @rails_session as written by each version's encrypted cookie jar with @secret
  # as secret_key_base (Rails 5.2 with use_authenticated_cookie_encryption = false).
  @rails_cookies [
    {"4.2", "SElPdVpvMGtid3ozbG8rMm9aekdJWnN3QU82VnZQZkZib3ZKU1dhVVJTN204cmtRZGJmakIzdFFLTi9vZng0Z0xjVUtnN3FBaVlHcmF5cEJ1UmJuSE50azJjR3FFeGRPQmgzRGNOSEJxT0c2bjhKWWF6SGdjbnp1RHRJWUFmRnVUWmJUVTdITU1adEZ5VVdTT2Z3aWNEbzlvcFhVM1cxN3NZWENaYzFhcE9OUjRiRUNLR3E0S2VtTUVZL1g5b2RlLS1NdWRZdnFXU2NJWTNsUWZqRW9Tdkh3PT0%3D--f33d7ceaf25e02cfe673c63737f336fb02df464b"},
    {"5.0", "VkNvUjRBaGdxdEZBdVdkRko1ZnB6ZmNtbkFseThsTksrR3I0dUkzaXo0ZW9lVmpxN2dGR05ZVFRxYUJKN0drTlZNUS83QUEvalNib1FYUXdxV1pCTkdaRTZUdzFXcVF3VEkvZHZSS3kzeHZMVWhQRDZwaGhEeGpPN2RWMmV1cCtReEsxeFdXSG9hQzlHZy9rSjE1NGo5Ym56MDBHRGxmU2VMSmtRQnZwVUlLczRQRVR2SjY5VWFYdTVDRUpCenFJLS0rSXllM2NjMkthUExCNUwrLzlrWFFnPT0%3D--346d0be19ab6f37e3ad57e6bba8fa37c7f10572c"},
    {"5.1", "OEpQM1g2YVF4NWxnejdHVkR6cWE3akE0NGVHSm1neEthQVpSL3c2RjJUQTZqUzQ3Qms4SmxhUjhFYUhBdWdjcVdzYWtmNDlPR0l5UG9jbGtEazZUN3hLMG1yQkJFUGJ4d0NpZWZFSnhqcHRSWDdlS2JSM2tKWUg2MlJiWVhZT1NWVlVReWRCbGErWU1Gb3A0VG5KbVpMdkdsbkdCc2xJT0tVZWxEYWVMUUlUWXIvTDlRS0gyWnFXL3Uzb0plYjVJLS1YVmJEbmwySGk2NXJPY3JITjdVcnpRPT0%3D--d0dd6526fdd27c3916695c5a903a5acc33516ee8"},
    {"5.2", "R051Qy9vZkdaWFE0ZE1YL1NSalZveVlyRmE3RjNSSDZRczFXa2w2ODdFalNwcGYyTDM3cHpsQ0dUdklIdklaOVFGY2pGTmtkVEFIOUZvK1lEeWdJa3BabTlYWkVLUjUxbGpwKzZPUzUwZ1p4elJDaHpDZzhOVXE4T1lWUU5CVnZSUTNLaGdYdHRIanRYZ2h0R2psdTlKQjNlWVI4TFFWTXRUbUxndXZFL3doZXFzNnR6T3NhT2ZnU1lHUkpqQTFWLS1wV0VhZDBLSStMZlZqalppd2FFWXp3PT0%3D--ae3da24ff2fbf28e823cd95aeba030151d472fba"}
  ]

  for {version, cookie} <- @rails_cookies do
    test "reads session cookies written by Rails #{version}" do
      conn = %{secret_key_base: @secret}
      assert CookieStore.get(conn, unquote(cookie), @rails_opts) == {nil, @rails_session}
    end
  end
end
