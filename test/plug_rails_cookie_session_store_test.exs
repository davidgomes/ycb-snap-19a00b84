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
  @authenticated_encrypted_opts @default_opts
                                |> Keyword.delete(:signing_salt)
                                |> Keyword.put(:authenticated_encryption, true)
                                |> Plug.Session.init()

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

  defmodule RawSerializer do
    def encode(binary), do: {:ok, binary}
    def decode(binary), do: {:ok, binary}
  end
  @rails_opts [key_length: 64, key_digest: :sha, serializer: RawSerializer]
  @rails_encrypted_opts CookieStore.init([encryption_salt: "encrypted cookie",
                                          signing_salt: "signed encrypted cookie"] ++ @rails_opts)
  @rails_authenticated_encrypted_opts CookieStore.init([authenticated_encryption: true,
                                                        encryption_salt: "authenticated encrypted cookie"] ++ @rails_opts)
  @rails_session ~s({"session_id":"4f2b5c0f1d8a7e6b9c3d2a1f0e9d8c7b","foo":"bar"})

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

  defp authenticated_encrypt_conn(conn) do
    put_in(conn.secret_key_base, @secret)
    |> Plug.Session.call(@authenticated_encrypted_opts)
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

  ## Authenticated encryption

  test "does not require signing_salt option with authenticated encryption" do
    assert @authenticated_encrypted_opts.store_config.signing_salt == nil
  end

  test "session cookies are encrypted with authenticated encryption" do
    conn = %{secret_key_base: @secret}
    cookie = CookieStore.put(conn, nil, %{foo: :bar}, @authenticated_encrypted_opts.store_config)
    assert is_binary(cookie)
    assert CookieStore.get(conn, cookie, @authenticated_encrypted_opts.store_config) == {nil, %{foo: :bar}}
    assert CookieStore.get(conn, cookie, @encrypted_opts.store_config) == {nil, %{}}
  end

  test "gets and sets session cookie with authenticated encryption" do
    conn = conn(:get, "/")
           |> authenticated_encrypt_conn()
           |> put_session(:foo, "bar")
           |> send_resp(200, "")
    assert conn(:get, "/")
           |> recycle_cookies(conn)
           |> authenticated_encrypt_conn()
           |> get_session(:foo) == "bar"
  end

  test "deletes session cookie with authenticated encryption" do
    conn = conn(:get, "/")
           |> authenticated_encrypt_conn()
           |> put_session(:foo, :bar)
           |> configure_session(drop: true)
           |> send_resp(200, "")
    assert conn(:get, "/")
           |> recycle_cookies(conn)
           |> authenticated_encrypt_conn()
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

  ## Rails compatibility

  test "reads session cookies encrypted by Rails 4.2" do
    cookie = "OVlWZXFGWEZTYXptdnVWZVNsVG9nYWNVVHJhbnJtdERqKzJuNVMvUTFqUUZkZFZ6QzhQeDZEOCs4U2pZcEVsRDZ5WXZsWjI0eGF2R3lUZFJQOUJiZEE9PS0tRUVtZ2tmTlZGYzJDbVlJVGMvYTRHUT09--a0e87191622cbe11022cf92a3f2985180c524e29"
    assert CookieStore.get(%{secret_key_base: @secret}, cookie, @rails_encrypted_opts) == {nil, @rails_session}
  end

  test "reads session cookies encrypted by Rails 5.1" do
    cookie = "d2FValpPSlpRakljVEtiWC84QzQ5a29FUk1DTzk0WXJ6c2FJTXVFNHRIUnlDM25HQ1YvaGxVVFRad28rZ3JWeUpTanovb1FPamRZY21sVlcrUGhwR0E9PS0tYmFTalU4bkh3REJOUnVySDVMK2NlZz09--7c1235665116a51b8b233b7df9a3e385f6e473fb"
    assert CookieStore.get(%{secret_key_base: @secret}, cookie, @rails_encrypted_opts) == {nil, @rails_session}
  end

  test "reads session cookies encrypted by Rails 5.2 with authenticated encryption" do
    cookie = "0hw3XiN9XqIHkUmBShDUbNp%2FTRlzeG3gw5AzK0Z%2Fi6%2BmZr%2F6PJ8rxZ9GwzNuyeNWPpUEiotNIkBPgkdhIQ%3D%3D--%2B%2FwUi8vsDvwaWMJr--oa%2FF%2FI4UvqI2sBwHRohQpw%3D%3D"
    assert CookieStore.get(%{secret_key_base: @secret}, cookie, @rails_authenticated_encrypted_opts) == {nil, @rails_session}
  end
end
