# Runtime Secrets

Some applications can't verify every token with a single, application wide `secret_key`. A multi tenant application may sign each tenant's tokens with its own key, or accept tokens issued by third parties alongside its own. In these cases the secret depends on the request.

The verify plugs (`Guardian.Plug.VerifyHeader`, `Guardian.Plug.VerifySession` and `Guardian.Plug.VerifyCookie`) accept a one argument function as the `:secret` option. It is called with the connection for each request and returns the secret to verify with.

## Selecting a secret from the connection

```elixir
defmodule AuthMe.Tenants do
  def secret_for_conn(%Plug.Conn{assigns: %{tenant: tenant}}), do: tenant.jwt_secret
  def secret_for_conn(_conn), do: nil
end
```

```elixir
pipeline :tenant_auth do
  plug AuthMe.LoadTenant
  plug Guardian.Plug.Pipeline, module: AuthMe.Guardian,
                               error_handler: AuthMe.AuthErrorHandler

  plug Guardian.Plug.VerifyHeader, secret: &AuthMe.Tenants.secret_for_conn/1
  plug Guardian.Plug.EnsureAuthenticated
  plug Guardian.Plug.LoadResource
end
```

The function runs after upstream plugs, so anything they put on the connection (assigns, path params, the host) is available. It may return any value `Guardian.Token.Jwt` accepts as a secret: a binary, a `%JOSE.JWK{}`, a JWK map, or a `{module, function, args}` tuple.

Use a remote capture such as `&AuthMe.Tenants.secret_for_conn/1`. Plug options are compiled into the pipeline, and anonymous functions can't be stored in module attributes or compiled plug options.

## Failing closed

If the function returns `nil`, verification fails with `:secret_not_found` and the error handler is called with:

```elixir
auth_error(conn, {:invalid_token, :secret_not_found}, opts)
```

It does **not** fall back to the configured `secret_key`. A lookup that quietly fails (an unknown tenant, a missing assign) must not verify tokens with the application wide key, since that would let one tenant's tokens authenticate against another.

The same applies anywhere a `:secret` option is given explicitly: only an absent `:secret` falls back to `secret_key`.

## Why not `{module, function, args}`?

A `{module, function, args}` tuple already has a meaning: `Guardian.Config.resolve_value/1` calls `apply(module, function, args)` without the connection. That keeps working as before in plug options:

```elixir
plug Guardian.Plug.VerifyHeader, secret: {AuthMe.Secrets, :current, []}
```

Only a one argument function is called with the connection.

## Refreshing from a cookie

When `Guardian.Plug.VerifyHeader` or `Guardian.Plug.VerifySession` fall back to a cookie via `:refresh_from_cookie`, the cookie is verified with the `:refresh_from_cookie` options, not the outer plug options. Pass the secret there as well:

```elixir
plug Guardian.Plug.VerifyHeader,
  secret: &AuthMe.Tenants.secret_for_conn/1,
  refresh_from_cookie: [secret: &AuthMe.Tenants.secret_for_conn/1]
```

The resolved secret is used both to verify the cookie token and to sign the exchanged access token.

## When the secret depends on the token

If the secret depends on the token itself, for example its `kid` header, use a custom `Guardian.Token.Jwt.SecretFetcher` instead. It receives the token headers but not the connection. See the `Guardian.Token.Jwt` documentation.
