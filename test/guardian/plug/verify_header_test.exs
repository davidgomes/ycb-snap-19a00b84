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

  defmodule TenantImpl do
    @moduledoc false

    use Guardian,
      otp_app: :guardian,
      token_module: Guardian.Token.Jwt,
      issuer: "MyApp",
      secret_key: "application-wide-secret"

    def subject_for_token(%{id: id}, _claims), do: {:ok, id}
    def resource_from_claims(%{"sub" => id}), do: {:ok, %{id: id}}
  end

  defmodule Tenants do
    @moduledoc false

    @secrets %{"acme" => "acme-secret", "globex" => "globex-secret"}

    def verifying_secret(conn) do
      send(self(), {:verifying_secret, conn.assigns[:tenant]})
      Map.get(@secrets, conn.assigns[:tenant])
    end

    def fixed_secret(secret), do: secret
  end

  defmodule TenantPipeline do
    @moduledoc false

    use Plug.Builder

    plug(Guardian.Plug.Pipeline, module: TenantImpl, error_handler: Handler)
    plug(VerifyHeader, secret: &Tenants.verifying_secret/1)
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

  describe "with a secret selected from the connection" do
    setup do
      opts = VerifyHeader.init(module: TenantImpl, error_handler: Handler, secret: &Tenants.verifying_secret/1)
      {:ok, %{tenant_opts: opts}}
    end

    test "verifies the token with the secret selected for the connection", ctx do
      {:ok, token, claims} = TenantImpl.encode_and_sign(@resource, %{}, secret: "acme-secret")

      conn =
        :get
        |> conn("/")
        |> assign(:tenant, "acme")
        |> put_req_header("authorization", "Bearer #{token}")
        |> VerifyHeader.call(ctx.tenant_opts)

      refute conn.status == 401
      assert Guardian.Plug.current_token(conn) == token
      assert Guardian.Plug.current_claims(conn) == claims
      assert_received {:verifying_secret, "acme"}
    end

    test "rejects a token signed with another tenant's secret", ctx do
      {:ok, token, _claims} = TenantImpl.encode_and_sign(@resource, %{}, secret: "globex-secret")

      conn =
        :get
        |> conn("/")
        |> assign(:tenant, "acme")
        |> put_req_header("authorization", "Bearer #{token}")
        |> VerifyHeader.call(ctx.tenant_opts)

      assert conn.status == 401
      assert conn.resp_body == inspect({:invalid_token, :invalid_token})
      refute Guardian.Plug.current_token(conn)
    end

    test "rejects the token instead of falling back to the secret_key when no secret is selected", ctx do
      {:ok, token, _claims} = TenantImpl.encode_and_sign(@resource)
      assert {:ok, _claims} = TenantImpl.decode_and_verify(token)

      conn =
        :get
        |> conn("/")
        |> assign(:tenant, "unknown")
        |> put_req_header("authorization", "Bearer #{token}")
        |> VerifyHeader.call(ctx.tenant_opts)

      assert conn.status == 401
      assert conn.halted
      assert conn.resp_body == inspect({:invalid_token, :secret_not_found})
      refute Guardian.Plug.current_token(conn)
    end

    test "does not select a secret when there is no token", ctx do
      conn =
        :get
        |> conn("/")
        |> assign(:tenant, "acme")
        |> VerifyHeader.call(ctx.tenant_opts)

      refute conn.status == 401
      refute Guardian.Plug.current_token(conn)
      refute_received {:verifying_secret, _}
    end

    test "does not select a secret when a token is already on the connection", ctx do
      {:ok, token, claims} = TenantImpl.encode_and_sign(%{id: "jane"}, %{}, secret: "acme-secret")

      conn =
        :get
        |> conn("/")
        |> assign(:tenant, "acme")
        |> put_req_header("authorization", "Bearer #{token}")
        |> Guardian.Plug.put_current_token(token)
        |> Guardian.Plug.put_current_claims(claims)
        |> VerifyHeader.call(ctx.tenant_opts)

      assert Guardian.Plug.current_token(conn) == token
      refute_received {:verifying_secret, _}
    end

    test "still resolves an {m, f, a} secret without the connection" do
      {:ok, token, claims} = TenantImpl.encode_and_sign(@resource, %{}, secret: "acme-secret")
      secret = {Tenants, :fixed_secret, ["acme-secret"]}

      conn =
        :get
        |> conn("/")
        |> put_req_header("authorization", "Bearer #{token}")
        |> VerifyHeader.call(VerifyHeader.init(module: TenantImpl, error_handler: Handler, secret: secret))

      refute conn.status == 401
      assert Guardian.Plug.current_claims(conn) == claims
    end

    test "accepts a remote capture as a compile time plug option" do
      {:ok, token, claims} = TenantImpl.encode_and_sign(@resource, %{}, secret: "globex-secret")

      conn =
        :get
        |> conn("/")
        |> assign(:tenant, "globex")
        |> put_req_header("authorization", "Bearer #{token}")
        |> TenantPipeline.call(TenantPipeline.init([]))

      refute conn.status == 401
      assert Guardian.Plug.current_claims(conn) == claims
      assert_received {:verifying_secret, "globex"}
    end

    test "selects the secret for the cookie with refresh_from_cookie" do
      {:ok, refresh_token, _claims} =
        TenantImpl.encode_and_sign(@resource, %{}, token_type: "refresh", secret: "acme-secret")

      conn =
        :get
        |> conn("/")
        |> assign(:tenant, "acme")
        |> put_req_cookie("guardian_default_token", refresh_token)
        |> Pipeline.put_module(TenantImpl)
        |> Pipeline.put_error_handler(Handler)
        |> VerifyHeader.call(refresh_from_cookie: [secret: &Tenants.verifying_secret/1])

      refute conn.halted
      access_token = Guardian.Plug.current_token(conn)
      assert {:ok, %{"typ" => "access"}} = TenantImpl.decode_and_verify(access_token, %{}, secret: "acme-secret")
      assert_received {:verifying_secret, "acme"}
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
