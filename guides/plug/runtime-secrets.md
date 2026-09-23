# Runtime Secrets

By default Guardian signs and verifies tokens with the `secret_key` configured
for your implementation module. Some applications need the verifying secret to
depend on the request instead. A multi-tenant application where every tenant
issues tokens with its own key is the common case, but the same applies to an
API that accepts tokens from several issuers told apart by host name or header.

## Selecting the secret from the connection

`Guardian.Plug.VerifyHeader` and `Guardian.Plug.VerifySession` accept a
`:secret` option. When it is a one argument function, the plug calls it with
the `Plug.Conn` once it has found a token, and verifies the token with whatever
the function returns.

```elixir
defmodule MyAppWeb.Tenants do
  def token_secret(conn) do
    case MyApp.Tenants.get_by_host(conn.host) do
      %{token_secret: secret} -> secret
      nil -> nil
    end
  end
end
```

```elixir
pipeline :api_auth do
  plug Guardian.Plug.Pipeline,
    module: MyApp.Guardian,
    error_handler: MyAppWeb.AuthErrorHandler

  plug Guardian.Plug.VerifyHeader, scheme: "Bearer", secret: &MyAppWeb.Tenants.token_secret/1
  plug Guardian.Plug.EnsureAuthenticated
  plug Guardian.Plug.LoadResource
end
```

A few things to keep in mind:

* The function is only called when the plug found a token and no token is
  already on the connection for its `:key`. Requests without a token never
  trigger the lookup.
* It runs where the plug sits in the pipeline, so it can read anything an
  earlier plug put on the connection, such as a tenant in `conn.assigns`.
* It may return any secret `Guardian.Token.Jwt` accepts: a binary, a JWK map, a
  `%JOSE.JWK{}` or an `{m, f, a}` tuple, which is then resolved as usual.
* Use a remote capture like `&MyAppWeb.Tenants.token_secret/1`. Plug options
  are compiled into the module by default and anonymous functions cannot be,
  so `secret: fn conn -> ... end` fails to compile in a router or pipeline.
* It runs for every request that carries a token. Cache the lookup if it is
  expensive.

## Returning `nil` rejects the token

If the function returns `nil`, Guardian does not fall back to the configured
`secret_key`. Verification fails with `:secret_not_found` and the error handler
is called with `{:invalid_token, :secret_not_found}`:

```elixir
defmodule MyAppWeb.AuthErrorHandler do
  @behaviour Guardian.Plug.ErrorHandler

  @impl Guardian.Plug.ErrorHandler
  def auth_error(conn, {:invalid_token, :secret_not_found}, _opts) do
    Plug.Conn.send_resp(conn, 401, "Unknown tenant")
  end

  def auth_error(conn, {type, _reason}, _opts) do
    Plug.Conn.send_resp(conn, 401, to_string(type))
  end
end
```

This is deliberate. If your implementation module also issues its own tokens
with `secret_key`, falling back would let a request for an unknown tenant be
authenticated with the application wide secret. The same applies to any
`:secret` that resolves to `nil`, including an `{m, f, a}` tuple. Leaving
`:secret` out entirely still uses `secret_key`.

## Refreshing from a cookie

The `:refresh_from_cookie` option takes its own list of options and does not
inherit `:secret` from the plug. Pass it again when refresh cookies are signed
per tenant too:

```elixir
plug Guardian.Plug.VerifySession,
  secret: &MyAppWeb.Tenants.token_secret/1,
  refresh_from_cookie: [secret: &MyAppWeb.Tenants.token_secret/1]
```

The resolved secret is used both to verify the refresh cookie and to sign the
access token it is exchanged for.

## Signing with the same secret

The verify plugs only verify. Pass the secret yourself when issuing tokens:

```elixir
secret = MyAppWeb.Tenants.token_secret(conn)

conn
|> MyApp.Guardian.Plug.sign_in(user, %{}, secret: secret)
|> MyApp.Guardian.Plug.remember_me(user, %{}, secret: secret)
```

A `nil` secret makes signing fail with `:secret_not_found` rather than sign
with `secret_key`.

## Functions and `{m, f, a}` tuples

An `{m, f, a}` tuple keeps the meaning `Guardian.Config.resolve_value/1` gives
it everywhere else: `apply(m, f, a)`, without the connection. It remains the
right choice for secrets that come from runtime configuration or a vault but do
not depend on the request. Use a one argument function when you need the
connection.

When the secret depends on the token itself, for example on its `kid` header
during key rotation, implement a `Guardian.Token.Jwt.SecretFetcher` instead. It
receives the token headers along with the options, including any `:secret` the
plug resolved.

Other token modules receive the resolved value as the `:secret` option and are
free to use or ignore it.

## Migrating from a wrapper plug

Before the `:secret` option accepted a function, selecting a secret per request
meant wrapping the verify plug:

```elixir
defmodule MyAppWeb.TenantVerifyHeader do
  @behaviour Plug

  def init(opts), do: opts

  def call(conn, opts) do
    opts = Keyword.put(opts, :secret, MyAppWeb.Tenants.token_secret(conn))
    Guardian.Plug.VerifyHeader.call(conn, opts)
  end
end
```

That wrapper has a trap: its `init/1` does not delegate to
`Guardian.Plug.VerifyHeader.init/1`, so the `:scheme` pattern is never compiled.
The fallback pattern then matches the whole header, `Bearer ` included, and
every token fails to verify with nothing pointing at the cause. It also looks
the secret up on every request, token or not.

Replace the wrapper with the option:

```elixir
plug Guardian.Plug.VerifyHeader, secret: &MyAppWeb.Tenants.token_secret/1
```

If you need to keep a wrapper, delegate `init/1` to
`Guardian.Plug.VerifyHeader.init/1`, and note that a `nil` secret it puts in
the options is now rejected instead of falling back to `secret_key`.
