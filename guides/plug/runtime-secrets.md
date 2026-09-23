# Runtime Secrets

By default the verify plugs check a token against the secret configured on your
implementation module (`secret_key`), or against a fixed `:secret` given to the
plug. Some applications have to pick the secret for each request instead. A
common case is a multi-tenant API that only verifies tokens issued by a third
party: every tenant has its own public key, and which tenant a request belongs
to is known from the request (its host, a path segment, ...), not from the
token.

`Guardian.Plug.VerifyHeader`, `Guardian.Plug.VerifySession` and
`Guardian.Plug.VerifyCookie` accept a one argument function as their `:secret`
option for this. The function is given the connection and returns the secret
to verify the token with.

## Selecting the secret from the connection

Put whatever identifies the tenant on the connection in an upstream plug, then
read it back in the secret function:

```elixir
defmodule MyAppWeb.Tenant do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    assign(conn, :current_tenant, MyApp.Tenants.get_by_host(conn.host))
  end

  def verifying_secret(conn) do
    case conn.assigns[:current_tenant] do
      %{public_key: pem} -> JOSE.JWK.from_pem(pem)
      _ -> nil
    end
  end
end
```

```elixir
defmodule MyAppWeb.AuthPipeline do
  use Guardian.Plug.Pipeline,
    otp_app: :my_app,
    module: MyApp.Guardian,
    error_handler: MyAppWeb.AuthErrorHandler

  plug MyAppWeb.Tenant
  plug Guardian.Plug.VerifyHeader, secret: &MyAppWeb.Tenant.verifying_secret/1
  plug Guardian.Plug.EnsureAuthenticated
end
```

The function can return anything the token module accepts as a secret. For
`Guardian.Token.Jwt` that is a binary, a JWK map or a `%JOSE.JWK{}`. Tokens
signed with an asymmetric key also need their algorithm listed in the
implementation module's `allowed_algos`, for example `["RS256"]`.

The function is only called once the plug has found a token to verify. When
there is no token, or a token has already been verified for the plug's `:key`,
it is not called, so a tenant lookup only happens for requests that carry a
token.

## Use a remote capture in `plug` options

Options given to `plug` are usually initialized when the pipeline is compiled
and embedded into the compiled code. Only values that can be escaped survive
that step. Remote captures such as `&MyAppWeb.Tenant.verifying_secret/1` can be,
anonymous functions cannot:

```
** (ArgumentError) cannot escape #Function<...>. The supported values are:
lists, tuples, maps, atoms, numbers, bitstrings, PIDs and remote functions in
the format &Mod.fun/arity
```

Anonymous functions are fine when you call the plug yourself, or when plugs are
initialized at runtime.

## Failing closed

If the function returns `nil` the token is rejected. The error handler is
called with `{:invalid_token, :secret_not_found}` and, unless `halt: false` is
set, the connection is halted. The configured `secret_key` is **not** used as a
fallback. This matters when one implementation module verifies both third
party tokens and tokens you issue yourself: a failed tenant lookup must not let
a token signed with your own secret through.

This holds for any explicit `:secret`, not only functions. Leaving `:secret`
out still uses `secret_key`, while `secret: nil`, or an `{m, f, a}` that returns
`nil`, fails with `:secret_not_found`.

## `{m, f, a}` secrets do not receive the connection

A `{module, function, args}` tuple keeps the meaning it has everywhere else in
Guardian (see `Guardian.Config.resolve_value/1`): it is resolved as
`apply(module, function, args)`, without the connection. An MFA that already
works as a plug option keeps working the same way. Use a function when you need
the connection.

## Refreshing from a cookie

With the `:refresh_from_cookie` option, or `Guardian.Plug.VerifyCookie`, the
token found in the cookie is exchanged for a new one. The secret for the cookie
goes in the refresh options:

```elixir
plug Guardian.Plug.VerifyHeader,
  secret: &MyAppWeb.Tenant.verifying_secret/1,
  refresh_from_cookie: [secret: &MyAppWeb.Tenant.refresh_secret/1]
```

That secret is used both to verify the cookie and to sign the exchanged token,
so it has to be able to sign: a shared secret or a private key, not a public
key.

## Selecting the secret from the token

When the secret depends on the token rather than on the request, for instance
on its `kid` header during a key rotation, use a custom
`Guardian.Token.Jwt.SecretFetcher`. Its `fetch_verifying_secret/3` callback
receives the token headers along with the options, including a `:secret` the
plug resolved from the connection, so the two approaches can be combined.

## Wrapping a verify plug

Before the `:secret` option accepted a function, selecting a secret per request
meant wrapping the verify plug in a plug of your own. If you still need a
wrapper, delegate `init/1` to the wrapped plug as well as `call/2`:

```elixir
defmodule MyAppWeb.VerifyHeader do
  alias Guardian.Plug.VerifyHeader

  def init(opts), do: VerifyHeader.init(opts)

  def call(conn, opts) do
    # adjust opts using the connection
    VerifyHeader.call(conn, opts)
  end
end
```

`Guardian.Plug.VerifyHeader.init/1` turns the `:scheme` option into the pattern
used to read the header. Without it the whole header value, `Bearer ` included,
is taken as the token and every token fails to verify.
