# Runtime Verifying Secrets

Most applications sign and verify every token with one secret, the `:secret_key`
of the implementation module. Multi tenant applications, and applications that
accept tokens issued by a third party, need to pick the verifying secret per
request instead: the tenant is only known once the request is in flight.

The verify plugs accept a `:secret` option for this. Any value that
`Guardian.Config.resolve_value/1` understands is valid, including a
`{module, function, args}` tuple, and a function of arity one is called with the
connection.

## Selecting the secret from the connection

```elixir
defmodule MyApp.AuthPipeline do
  use Guardian.Plug.Pipeline,
    otp_app: :my_app,
    module: MyApp.Tokens,
    error_handler: MyApp.AuthErrorHandler

  plug Guardian.Plug.VerifyHeader, scheme: "Bearer", secret: &MyApp.Tenants.verifying_secret/1
  plug Guardian.Plug.EnsureAuthenticated
end
```

```elixir
defmodule MyApp.Tenants do
  def verifying_secret(conn) do
    with [tenant_id] <- Plug.Conn.get_req_header(conn, "x-tenant-id"),
         %{secret: secret} <- MyApp.Tenants.get_by_id(tenant_id) do
      secret
    else
      _ -> nil
    end
  end
end
```

The same option works on `Guardian.Plug.VerifySession` and
`Guardian.Plug.VerifyCookie`.

## A failed lookup rejects the token

Returning `nil` does not fall back to the implementation module's
`:secret_key`. A token verified against the application's own secret because a
tenant lookup quietly failed would be a tenant isolation failure, so an explicit
`:secret` that resolves to `nil` fails with `{:error, :secret_not_found}` and the
pipeline's error handler is called with:

```elixir
auth_error(conn, {:invalid_token, :secret_not_found}, opts)
```

Omitting `:secret` altogether still uses the configured `:secret_key` as before.
Only a `:secret` that is present and resolves to `nil` fails.

## How often the function is called

The function is resolved once per plug that reads the option, on every request
that reaches it. Two verify plugs in the same pipeline resolve it twice. Because
the option invites database and JWKS lookups written inline, cache them yourself
if the cost matters:

```elixir
def verifying_secret(conn) do
  case Plug.Conn.get_req_header(conn, "x-tenant-id") do
    [tenant_id] -> MyApp.Tenants.cached_secret(tenant_id)
    _ -> nil
  end
end
```

`:refresh_from_cookie` does not inherit the secret from the plug that triggered
it. It exchanges the cookie token through its own options, so give the cookie
path its own `:secret` when it needs one:

```elixir
plug Guardian.Plug.VerifyHeader,
  secret: &MyApp.Tenants.verifying_secret/1,
  refresh_from_cookie: [secret: &MyApp.Tenants.verifying_secret/1]
```

## The contract

* The function must have arity one. A function of any other arity raises
  `ArgumentError` rather than being silently ignored.
* The connection is the only argument. It is the connection as it exists when the
  verify plug runs, so anything an upstream plug assigned is available.
* `{module, function, args}` keeps its existing meaning of
  `apply(module, function, args)` with no connection. That form works in plug
  options and in calls such as `MyApp.Tokens.decode_and_verify/3` alike.

## Signing with the same secret

`:secret` is not plug specific. `Guardian.Plug.sign_in/4` and the encoding
functions take the same option, so a tenant scoped token can be issued with the
tenant's secret:

```elixir
MyApp.Guardian.Plug.sign_in(conn, user, %{}, secret: MyApp.Tenants.secret_for(tenant))
```

Only the verify plugs resolve a function against the connection. Elsewhere, pass
the resolved secret value.

## When to use a `SecretFetcher` instead

`:secret` picks a secret from the request. When the choice depends on the token
itself, typically a `kid` header naming one key of a rotating set, implement a
`Guardian.Token.Jwt.SecretFetcher` instead: it receives the token headers.

```elixir
defmodule MyApp.SecretFetcher do
  use Guardian.Token.Jwt.SecretFetcher

  def fetch_verifying_secret(_mod, %{"kid" => kid}, _opts) do
    case MyApp.Keys.fetch(kid) do
      {:ok, jwk} -> {:ok, jwk}
      :error -> {:error, :secret_not_found}
    end
  end

  def fetch_verifying_secret(_mod, _headers, _opts), do: {:error, :secret_not_found}
end
```

The two compose: a `SecretFetcher` still receives the plug options, so it can
read a `:secret` that a verify plug already resolved from the connection.
