defmodule PlugRailsCookieSessionStoreTest do
  use ExUnit.Case, async: true
  use Plug.Test

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
  @authenticated_encrypted_opts Plug.Session.init(
    @default_opts |> Keyword.put(:cipher, :aes_256_gcm) |> Keyword.delete(:signing_salt))

  defmodule RailsJSONSerializer do
    def encode(%{"foo" => "bar"}), do: {:ok, ~s({"foo":"bar"})}
    def decode(~s({"foo":"bar"})), do: {:ok, %{"foo" => "bar"}}
    def decode(_), do: :error
  end

  @rails_opts [
    store: CookieStore,
    key: "_app_session",
    key_iterations: 1000,
    key_length: 64,
    key_digest: :sha,
    serializer: RailsJSONSerializer
  ]
  @rails_cbc_opts @rails_opts
                  |> Keyword.put(:encryption_salt, "encrypted cookie")
                  |> Keyword.put(:signing_salt, "signed encrypted cookie")
                  |> CookieStore.init()
  @rails_gcm_opts @rails_opts
                  |> Keyword.put(:encryption_salt, "authenticated encrypted cookie")
                  |> Keyword.put(:cipher, :aes_256_gcm)
                  |> CookieStore.init()

  # Generated with ActiveSupport::MessageEncryptor, see the Rails options above.
  @rails_4_cookie "aVFpbU9XN1hmdkRuWDd6QnZyV3dJdz09LS1YcjdqUkJOb3NSWVZqSXN1Ym9zdVdnPT0%3D--c16c816591acc749bc3622b5c091ff5abb55dcc2"
  @rails_5_cookie "UmJ5amhsU1VWaVFaT2xldTh6a0NVUT09LS11T1RVaXN1ZklBcXNqdUVOR3NDOEVnPT0%3D--a9c0525287f8c1b6369f207e6b3bc14e1685b9b3"
  @rails_5_2_cookie "n2ltzPMS5EjUb6%2FQhA%3D%3D--OC6yK7i7PXwg2jCG--xHcrZHlhHVNrEGFMAxRidw%3D%3D"

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

  test "does not require signing_salt with authenticated encryption" do
    assert @authenticated_encrypted_opts.store_config.signing_salt == nil
    assert @authenticated_encrypted_opts.store_config.cipher == :aes_256_gcm
  end

  test "requires cipher option to be supported" do
    assert_raise ArgumentError, ~r/expects :cipher option/, fn ->
      Plug.Session.init(Keyword.put(@default_opts, :cipher, :des))
    end
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

  ## Rails compatibility

  test "reads Rails 4 encrypted session cookies" do
    conn = %{secret_key_base: @secret}
    assert CookieStore.get(conn, @rails_4_cookie, @rails_cbc_opts) == {nil, %{"foo" => "bar"}}
  end

  test "reads Rails 5.0 and 5.1 encrypted session cookies" do
    conn = %{secret_key_base: @secret}
    assert CookieStore.get(conn, @rails_5_cookie, @rails_cbc_opts) == {nil, %{"foo" => "bar"}}
  end

  test "reads Rails 5.2 authenticated encrypted session cookies" do
    conn = %{secret_key_base: @secret}
    assert CookieStore.get(conn, @rails_5_2_cookie, @rails_gcm_opts) == {nil, %{"foo" => "bar"}}
    assert CookieStore.get(conn, @rails_5_2_cookie, @rails_cbc_opts) == {nil, %{}}
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
end
