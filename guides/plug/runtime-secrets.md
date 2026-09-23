# Runtime Secrets

Most applications verify every token with the single `secret_key` configured on
the implementation module. Some need to pick the secret per request instead:

* A multi-tenant API where each tenant signs its own tokens
* Tokens issued by a third party whose key depends on the host or a header
* A gradual key rotation keyed by something on the request

The verify plugs (`Guardian.Plug.VerifyHeader`, `Guardian.Plug.VerifySession`
and `Guardian.Plug.VerifyCookie`) accept a one argument function as the
`:secret` option. Once a token has been found, the function is called with the
connection and whatever it returns is used as the secret for that request.

## Selecting the secret from the connection

```elixir
defmodule MyApp.Tenants do
  def secret_for_conn(conn) do
    case MyApp.Tenants.get_by_host(conn.host) do
      %{jwt_secret: secret} -> secret
      nil -> nil
    end
  end
end
```

```elixir
defmodule MyApp.AuthPipeline do
  use Guardian.Plug.Pipeline,
    otp_app: :my_app,
    module: MyApp.Guardian,
    error_handler: MyApp.AuthErrorHandler

  plug Guardian.Plug.VerifyHeader, secret: &MyApp.Tenants.secret_for_conn/1
  plug Guardian.Plug.EnsureAuthenticated
  plug Guardian.Plug.LoadResource
end
```

The function may return anything the token module accepts as a secret. For
`Guardian.Token.Jwt` that is a binary, a JWK map, a `%JOSE.JWK{}` or an
`{m, f, a}` tuple.

The function is only called when a token is present, so requests without a
token do not pay for the lookup.

Use a remote capture such as `&MyApp.Tenants.secret_for_conn/1` rather than an
anonymous function. Phoenix initializes plugs at compile time by default and
anonymous functions cannot be stored in the compiled plug options.

## Failing closed

If the function returns `nil`, verification fails with
`{:error, :secret_not_found}` and the error handler is called with
`{:invalid_token, :secret_not_found}`. The configured `secret_key` is **not**
used as a fallback.

This matters when the same implementation module handles tokens from several
issuers. A tenant lookup that quietly returns `nil` must reject the request
rather than verify it against the application wide secret.

The same applies anywhere a secret is passed explicitly: `secret: nil` fails,
while omitting `:secret` entirely still uses the configured `secret_key`.

```elixir
defmodule MyApp.AuthErrorHandler do
  import Plug.Conn

  @behaviour Guardian.Plug.ErrorHandler

  @impl Guardian.Plug.ErrorHandler
  def auth_error(conn, {:invalid_token, :secret_not_found}, _opts) do
    send_resp(conn, 401, "unknown tenant")
  end

  def auth_error(conn, {type, _reason}, _opts) do
    send_resp(conn, 401, to_string(type))
  end
end
```

## Refreshing from a cookie

`Guardian.Plug.VerifyCookie` uses the `:secret` both to verify the refresh
token in the cookie and to sign the access token it is exchanged for.

When `Guardian.Plug.VerifyHeader` or `Guardian.Plug.VerifySession` fall back to
the cookie with `:refresh_from_cookie`, the cookie is handled with the options
given to `:refresh_from_cookie`, so pass the secret there too:

```elixir
plug Guardian.Plug.VerifyHeader,
  secret: &MyApp.Tenants.secret_for_conn/1,
  refresh_from_cookie: [secret: &MyApp.Tenants.secret_for_conn/1]
```

## `{m, f, a}` tuples are not called with the connection

An `{m, f, a}` tuple keeps its existing meaning everywhere: it is resolved by
`Guardian.Config.resolve_value/1`, which calls `apply(m, f, a)` without the
connection. Use a one argument function when you need the connection.

## Why not wrap the plug?

Before the `:secret` function was supported, selecting a secret per request
meant wrapping a verify plug:

```elixir
defmodule MyApp.TenantVerifyHeader do
  @behaviour Plug

  def init(opts), do: Guardian.Plug.VerifyHeader.init(opts)

  def call(conn, opts) do
    secret = MyApp.Tenants.secret_for_conn(conn)
    Guardian.Plug.VerifyHeader.call(conn, Keyword.put(opts, :secret, secret))
  end
end
```

This still works, but it is easy to get wrong. `init/1` must delegate to
`Guardian.Plug.VerifyHeader.init/1`, otherwise the scheme regex is never
compiled, the whole `Authorization` header (including `Bearer `) is treated as
the token, and every token silently fails to verify. Passing a function as
`:secret` avoids the wrapper entirely.

## Custom secret fetchers

When the secret depends on the token itself, for example on the `kid` header,
implement a `Guardian.Token.Jwt.SecretFetcher` instead. The fetcher receives the
token headers and the options, including the secret resolved from the
connection, so both approaches can be combined.
