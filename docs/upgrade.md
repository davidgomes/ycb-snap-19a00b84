# Upgrading from 1.x to 2.0

Canary 2.0 adds LiveView support with `Canary.Hooks`. Plugs and hooks share the same options,
and the same logic is used to resolve the subject, the resource and the error handler.

## Error handler

The `:unauthorized_handler` and `:not_found_handler` config options are deprecated.
Implement the `Canary.ErrorHandler` behaviour and set it in config instead:

```elixir
# before
config :canary,
  unauthorized_handler: {YourApp.ErrorHandler, :handle_unauthorized},
  not_found_handler: {YourApp.ErrorHandler, :handle_not_found}

# after
config :canary, error_handler: YourApp.ErrorHandler
```

```elixir
defmodule YourApp.ErrorHandler do
  @behaviour Canary.ErrorHandler

  @impl true
  def unauthorized_handler(%Plug.Conn{} = conn), do: YourAppWeb.Helpers.handle_unauthorized(conn)
  def unauthorized_handler(%Phoenix.LiveView.Socket{} = socket), do: {:halt, Phoenix.LiveView.redirect(socket, to: "/")}

  @impl true
  def not_found_handler(%Plug.Conn{} = conn), do: YourAppWeb.Helpers.handle_not_found(conn)
  def not_found_handler(%Phoenix.LiveView.Socket{} = socket), do: {:halt, Phoenix.LiveView.redirect(socket, to: "/")}
end
```

Until you migrate, `Canary.DefaultHandler` keeps calling the deprecated handlers for plugs.

The error handler can be overridden for a single plug or hook:

```elixir
plug :load_and_authorize_resource,
  model: Post,
  error_handler: YourApp.CustomErrorHandler

mount_canary :load_and_authorize_resource,
  model: Post,
  unauthorized_handler: {YourApp.CustomErrorHandler, :special_unauthorized_handler}
```

The handler is resolved in the following order: `:unauthorized_handler` / `:not_found_handler` option,
`:error_handler` option, `:error_handler` config, `Canary.DefaultHandler`.

## Subject

Both `Canary.Plugs` and `Canary.Hooks` raise `KeyError` when the subject key (`:current_user` by default)
is missing in the assigns. Make sure it's always assigned - it can be `nil` for anonymous users.

## `:id_name` and `:id_field`

Both options accept an atom or a string, so `id_name: :post_id, id_field: :slug` works
the same as `id_name: "post_id", id_field: "slug"`.

## Plug only options

`:persisted`, `:non_id_actions` and loading all resources on the `:index` action are available only in `Canary.Plugs`.
In `Canary.Hooks` use `:required` to load a resource, and `authorize_resource` for non-id actions.
