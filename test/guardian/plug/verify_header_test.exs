defmodule Guardian.Plug.VerifyHeaderTest do
  @moduledoc false

  import Plug.Test
  import Plug.Conn
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Guardian.Plug.Pipeline
  alias Guardian.Plug.VerifyHeader

  defmodule Handler do
    @moduledoc false

    import Plug.Conn

    @behaviour Guardian.Plug.ErrorHandler

    @impl Guardian.Plug.ErrorHandler
    def auth_error(conn, {type, reason}, _opts) do
      body = inspect({type, reason})
      send_resp(conn, 401, body)
    end
  end

  defmodule Impl do
    @moduledoc false

    use Guardian,
      otp_app: :guardian,
      token_module: Guardian.Support.TokenModule

    def subject_for_token(%{id: id}, _claims), do: {:ok, id}
    def subject_for_token(%{"id" => id}, _claims), do: {:ok, id}

    def resource_from_claims(%{"sub" => id}), do: {:ok, %{id: id}}
  end

  @resource %{id: "bobby"}

  setup do
    impl = __MODULE__.Impl
    handler = __MODULE__.Handler
    {:ok, token, claims} = __MODULE__.Impl.encode_and_sign(@resource)
    {:ok, %{claims: claims, conn: conn(:get, "/"), token: token, impl: impl, handler: handler}}
  end

  test "with no token" do
    conn = :get |> conn("/") |> VerifyHeader.call([])

    refute conn.status == 401
    assert Guardian.Plug.current_token(conn, []) == nil
    assert Guardian.Plug.current_claims(conn, []) == nil
  end

  test "it uses the module from options", ctx do
    conn =
      :get
      |> conn("/")
      |> put_req_header("authorization", ctx.token)
      |> VerifyHeader.call(module: ctx.impl)

    refute conn.status == 401
    assert Guardian.Plug.current_token(conn, []) == ctx.token
    assert Guardian.Plug.current_claims(conn, []) == ctx.claims
  end

  test "it finds the module from the pipeline", ctx do
    conn =
      :get
      |> conn("/")
      |> put_req_header("authorization", ctx.token)
      |> Pipeline.put_module(ctx.impl)
      |> VerifyHeader.call([])

    refute conn.status == 401
    assert Guardian.Plug.current_token(conn, []) == ctx.token
    assert Guardian.Plug.current_claims(conn, []) == ctx.claims
  end

  test "with an existing token on the connection it leaves it intact", ctx do
    {:ok, token, claims} = apply(ctx.impl, :encode_and_sign, [%{id: "jane"}])

    conn =
      :get
      |> conn("/")
      |> put_req_header("authorization", ctx.token)
      |> Guardian.Plug.put_current_token(token)
      |> Guardian.Plug.put_current_claims(claims)
      |> VerifyHeader.call([])

    refute conn.status == 401
    assert Guardian.Plug.current_token(conn) == token
    assert Guardian.Plug.current_claims(conn) == claims
  end

  test "with no module", ctx do
    assert_raise RuntimeError, "`module` not set in Guardian pipeline", fn ->
      :get
      |> conn("/")
      |> put_req_header("authorization", ctx.token)
      |> VerifyHeader.call([])
    end
  end

  test "with a key specified", ctx do
    conn =
      :get
      |> conn("/")
      |> put_req_header("authorization", ctx.token)
      |> VerifyHeader.call(module: ctx.impl, key: :secret)

    refute Guardian.Plug.current_token(conn)
    refute Guardian.Plug.current_claims(conn)

    assert Guardian.Plug.current_token(conn, key: :secret) == ctx.token
    assert Guardian.Plug.current_claims(conn, key: :secret) == ctx.claims
  end

  test "with :realm option shows a warning message" do
    has_warning_message =
      :stderr
      |> capture_io(fn -> VerifyHeader.init(realm: "Bearer") end)
      |> String.contains?("`:realm` option is deprecated; please rename `:realm` to `:scheme` option instead.")

    assert has_warning_message
  end

  test "getting the scheme config" do
    opts = VerifyHeader.init(scheme: "Bearer")
    assert opts[:scheme_reg] == "Bearer:? +(.*)$"

    opts = VerifyHeader.init(scheme: "Basic")
    assert opts[:scheme_reg] == "Basic:? +(.*)$"
  end

  test "correctly reading the token from the header", ctx do
    conn =
      :get
      |> conn("/")
      |> put_req_header("authorization", "Basic #{ctx.token}")
      |> VerifyHeader.call(
        Keyword.merge(VerifyHeader.init(scheme: "Basic"), module: ctx.impl, error_handler: ctx.handler)
      )

    refute conn.status == 401
    assert Guardian.Plug.current_token(conn) == ctx.token
  end

  test "ignoring token from header with non-matching scheme", ctx do
    conn =
      :get
      |> conn("/")
      |> put_req_header("authorization", "Bearer #{ctx.token}")
      |> VerifyHeader.call(
        Keyword.merge(VerifyHeader.init(scheme: "Basic"), module: ctx.impl, error_handler: ctx.handler)
      )

    refute Guardian.Plug.current_token(conn) == ctx.token
  end

  test "with a token and mismatching claims", ctx do
    conn =
      :get
      |> conn("/")
      |> put_req_header("authorization", ctx.token)
      |> VerifyHeader.call(module: ctx.impl, error_handler: ctx.handler, claims: %{no: "way"})

    assert conn.status == 401
    assert conn.resp_body == inspect({:invalid_token, "no"})
  end

  test "with a token and matching claims", ctx do
    conn =
      :get
      |> conn("/")
      |> put_req_header("authorization", ctx.token)
      |> VerifyHeader.call(module: ctx.impl, error_handler: ctx.handler, claims: ctx.claims)

    refute conn.status == 401
    assert Guardian.Plug.current_token(conn) == ctx.token
    assert Guardian.Plug.current_claims(conn) == ctx.claims
  end

  test "with a token and no specified claims", ctx do
    conn =
      :get
      |> conn("/")
      |> put_req_header("authorization", ctx.token)
      |> VerifyHeader.call(module: ctx.impl, error_handler: ctx.handler)

    refute conn.status == 401
    assert Guardian.Plug.current_token(conn) == ctx.token
    assert Guardian.Plug.current_claims(conn) == ctx.claims
  end

  test "with an invalid token", ctx do
    conn =
      :get
      |> conn("/")
      |> put_req_header("authorization", "not a good one")
      |> VerifyHeader.call(module: ctx.impl, error_handler: ctx.handler)

    assert conn.status == 401
    assert conn.halted
  end

  test "does not halt conn when option is set to false", ctx do
    conn =
      :get
      |> conn("/")
      |> put_req_header("authorization", "not a good one")
      |> VerifyHeader.call(module: ctx.impl, error_handler: ctx.handler, halt: false)

    assert conn.status == 401
    refute conn.halted
  end

  describe "with a :secret option" do
    defmodule TenantImpl do
      @moduledoc false

      use Guardian,
        otp_app: :guardian,
        token_module: Guardian.Token.Jwt,
        issuer: "MyApp",
        secret_key: "application-wide-secret"

      def subject_for_token(%{id: id}, _claims), do: {:ok, "User:#{id}"}
      def resource_from_claims(%{"sub" => "User:" <> sub}), do: {:ok, %{id: sub}}

      def static_secret(secret), do: secret
    end

    @tenant_secrets %{"acme" => "acme-secret", "globex" => "globex-secret"}

    def tenant_secret(conn) do
      send(self(), :tenant_secret_called)

      case get_req_header(conn, "x-tenant") do
        [tenant] -> Map.get(@tenant_secrets, tenant)
        _ -> nil
      end
    end

    setup do
      opts =
        VerifyHeader.init(
          module: __MODULE__.TenantImpl,
          error_handler: __MODULE__.Handler,
          secret: &__MODULE__.tenant_secret/1
        )

      {:ok, %{opts: opts, impl: __MODULE__.TenantImpl}}
    end

    defp tenant_conn(tenant, token) do
      :get
      |> conn("/")
      |> put_req_header("x-tenant", tenant)
      |> put_req_header("authorization", "Bearer #{token}")
    end

    test "verifies with the secret selected from the connection", ctx do
      {:ok, token, claims} = ctx.impl.encode_and_sign(@resource, %{}, secret: "acme-secret")

      conn = "acme" |> tenant_conn(token) |> VerifyHeader.call(ctx.opts)

      refute conn.halted
      assert Guardian.Plug.current_token(conn) == token
      assert Guardian.Plug.current_claims(conn) == claims
      assert_received :tenant_secret_called
    end

    test "rejects a token signed for another tenant", ctx do
      {:ok, token, _} = ctx.impl.encode_and_sign(@resource, %{}, secret: "acme-secret")

      conn = "globex" |> tenant_conn(token) |> VerifyHeader.call(ctx.opts)

      assert conn.halted
      assert conn.resp_body == inspect({:invalid_token, :invalid_token})
      refute Guardian.Plug.current_token(conn)
    end

    test "does not fall back to the configured secret when no secret is found", ctx do
      {:ok, token, _} = ctx.impl.encode_and_sign(@resource)
      assert {:ok, _} = ctx.impl.decode_and_verify(token)

      conn = "unknown" |> tenant_conn(token) |> VerifyHeader.call(ctx.opts)

      assert conn.halted
      assert conn.status == 401
      assert conn.resp_body == inspect({:invalid_token, :secret_not_found})
      refute Guardian.Plug.current_token(conn)
      refute Guardian.Plug.current_claims(conn)
    end

    test "does not call the function without a token", ctx do
      conn = :get |> conn("/") |> put_req_header("x-tenant", "acme") |> VerifyHeader.call(ctx.opts)

      refute conn.halted
      refute Guardian.Plug.current_token(conn)
      refute_received :tenant_secret_called
    end

    test "does not call the function when a token is already on the connection", ctx do
      {:ok, token, claims} = ctx.impl.encode_and_sign(@resource, %{}, secret: "acme-secret")

      conn =
        "acme"
        |> tenant_conn(token)
        |> Guardian.Plug.put_current_token("existing")
        |> Guardian.Plug.put_current_claims(claims)
        |> VerifyHeader.call(ctx.opts)

      assert Guardian.Plug.current_token(conn) == "existing"
      refute_received :tenant_secret_called
    end

    test "still resolves an {m, f, a} without the connection", ctx do
      {:ok, token, claims} = ctx.impl.encode_and_sign(@resource, %{}, secret: "acme-secret")
      opts = Keyword.put(ctx.opts, :secret, {ctx.impl, :static_secret, ["acme-secret"]})

      conn = "globex" |> tenant_conn(token) |> VerifyHeader.call(opts)

      refute conn.halted
      assert Guardian.Plug.current_claims(conn) == claims
    end

    test "uses the refresh_from_cookie :secret to verify the cookie and sign the new token", ctx do
      {:ok, refresh_token, _} = ctx.impl.encode_and_sign(@resource, %{}, token_type: "refresh", secret: "acme-secret")

      opts = Keyword.put(ctx.opts, :refresh_from_cookie, secret: &__MODULE__.tenant_secret/1)

      conn =
        :get
        |> conn("/")
        |> put_req_header("x-tenant", "acme")
        |> put_req_cookie("guardian_default_token", refresh_token)
        |> Pipeline.put_module(ctx.impl)
        |> Pipeline.put_error_handler(__MODULE__.Handler)
        |> VerifyHeader.call(opts)

      refute conn.halted
      assert new_token = Guardian.Plug.current_token(conn)
      assert %{"sub" => "User:bobby", "typ" => "access"} = Guardian.Plug.current_claims(conn)
      assert {:ok, _} = ctx.impl.decode_and_verify(new_token, %{}, secret: "acme-secret")
      assert {:error, :invalid_token} = ctx.impl.decode_and_verify(new_token)
    end

    test "rejects the refresh cookie when its :secret function finds no secret", ctx do
      {:ok, refresh_token, _} = ctx.impl.encode_and_sign(@resource, %{}, token_type: "refresh")

      conn =
        :get
        |> conn("/")
        |> put_req_header("x-tenant", "unknown")
        |> put_req_cookie("guardian_default_token", refresh_token)
        |> Pipeline.put_module(ctx.impl)
        |> Pipeline.put_error_handler(__MODULE__.Handler)
        |> VerifyHeader.call(Keyword.put(ctx.opts, :refresh_from_cookie, secret: &__MODULE__.tenant_secret/1))

      assert conn.halted
      assert conn.resp_body == inspect({:invalid_token, :secret_not_found})
      refute Guardian.Plug.current_token(conn)
    end
  end

  describe "with refresh_from_cookie option" do
    defmodule ImplJwt do
      @moduledoc false

      use Guardian,
        otp_app: :guardian,
        token_module: Guardian.Token.Jwt,
        issuer: "MyApp",
        verify_issuer: true,
        secret_key: "foo-de-fafa",
        allowed_algos: ["HS512", "ES512"],
        ttl: {4, :weeks},
        secret_fetcher: Guardian.Support.TokenModule.SecretFetcher,
        token_ttl: %{
          "access" => {1, :day},
          "refresh" => {2, :weeks}
        },
        handler: __MODULE__.Handler

      def subject_for_token(%{id: id}, _claims), do: {:ok, "User:#{id}"}
      def resource_from_claims(%{"sub" => "User:" <> sub}), do: {:ok, %{id: sub}}

      def the_secret_yo, do: config(:secret_key)
      def the_secret_yo(val), do: val

      def verify_claims(claims, opts) do
        if Keyword.get(opts, :fail_owner_verify_claims) do
          {:error, Keyword.get(opts, :fail_owner_verify_claims)}
        else
          {:ok, claims}
        end
      end

      def build_claims(claims, _opts) do
        Map.put(claims, "from_owner", "here")
      end
    end

    setup do
      impl = __MODULE__.ImplJwt
      handler = __MODULE__.Handler
      {:ok, token, claims} = __MODULE__.ImplJwt.encode_and_sign(@resource)
      {:ok, %{claims: claims, conn: conn(:get, "/"), token: token, impl: impl, handler: handler}}
    end

    test "when session is valid", ctx do
      conn =
        :get
        |> conn("/")
        |> put_req_header("authorization", ctx.token)
        |> Pipeline.put_module(ctx.impl)
        |> Pipeline.put_error_handler(ctx.handler)
        |> VerifyHeader.call(refresh_from_cookie: [])

      assert Guardian.Plug.current_token(conn, []) == ctx.token
      assert Guardian.Plug.current_claims(conn, []) == ctx.claims
    end

    test "when session is expired", ctx do
      {:ok, expired_token, _} = apply(ctx.impl, :encode_and_sign, [%{id: "jane"}, %{}, [ttl: {0, :second}]])
      {:ok, refresh_token, _} = apply(ctx.impl, :encode_and_sign, [%{id: "jane"}, %{}, [token_type: "refresh"]])
      :timer.sleep(1000)
      assert {:error, :token_expired} = apply(ctx.impl, :decode_and_verify, [expired_token])

      conn =
        :get
        |> conn("/")
        |> put_req_cookie("guardian_default_token", refresh_token)
        |> put_req_header("authorization", expired_token)
        |> Pipeline.put_module(ctx.impl)
        |> Pipeline.put_error_handler(ctx.handler)
        |> VerifyHeader.call(refresh_from_cookie: [])

      refute conn.halted
      assert new_access_token = Guardian.Plug.current_token(conn)
      assert {:ok, _} = apply(ctx.impl, :decode_and_verify, [new_access_token])
      assert %{"sub" => "User:jane", "typ" => "access"} = Guardian.Plug.current_claims(conn)
    end

    test "when session is expired and refresh_from_cookie: true", ctx do
      {:ok, expired_token, _} = apply(ctx.impl, :encode_and_sign, [%{id: "jane"}, %{}, [ttl: {0, :second}]])
      {:ok, refresh_token, _} = apply(ctx.impl, :encode_and_sign, [%{id: "jane"}, %{}, [token_type: "refresh"]])
      :timer.sleep(1000)
      assert {:error, :token_expired} = apply(ctx.impl, :decode_and_verify, [expired_token])

      conn =
        :get
        |> conn("/")
        |> put_req_cookie("guardian_default_token", refresh_token)
        |> put_req_header("authorization", expired_token)
        |> Pipeline.put_module(ctx.impl)
        |> Pipeline.put_error_handler(ctx.handler)
        |> VerifyHeader.call(refresh_from_cookie: true)

      refute conn.halted
      assert new_access_token = Guardian.Plug.current_token(conn)
      assert {:ok, _} = apply(ctx.impl, :decode_and_verify, [new_access_token])
      assert %{"sub" => "User:jane", "typ" => "access"} = Guardian.Plug.current_claims(conn)
    end

    test "when session is invalid", ctx do
      {:ok, token, _} = apply(ctx.impl, :encode_and_sign, [%{id: "jane"}])
      invalid_token = "#{token}whatever"
      {:ok, refresh_token, _} = apply(ctx.impl, :encode_and_sign, [%{id: "jane"}, %{}, [token_type: "refresh"]])

      conn =
        :get
        |> conn("/")
        |> put_req_cookie("guardian_default_token", refresh_token)
        |> put_req_header("authorization", invalid_token)
        |> Pipeline.put_module(ctx.impl)
        |> Pipeline.put_error_handler(ctx.handler)
        |> VerifyHeader.call(refresh_from_cookie: [module: ctx.impl])

      refute conn.halted
      assert new_access_token = Guardian.Plug.current_token(conn)
      assert {:ok, _} = apply(ctx.impl, :decode_and_verify, [new_access_token])
      assert %{"sub" => "User:jane", "typ" => "access"} = Guardian.Plug.current_claims(conn)
    end

    test "when no header found", ctx do
      {:ok, refresh_token, _} = apply(ctx.impl, :encode_and_sign, [%{id: "jane"}, %{}, [token_type: "refresh"]])

      conn =
        :get
        |> conn("/")
        |> put_req_cookie("guardian_default_token", refresh_token)
        |> Pipeline.put_module(ctx.impl)
        |> Pipeline.put_error_handler(ctx.handler)
        |> VerifyHeader.call(refresh_from_cookie: [module: ctx.impl])

      refute conn.halted
      assert new_access_token = Guardian.Plug.current_token(conn)
      assert {:ok, _} = apply(ctx.impl, :decode_and_verify, [new_access_token])
      assert %{"sub" => "User:jane", "typ" => "access"} = Guardian.Plug.current_claims(conn)
    end
  end
end
