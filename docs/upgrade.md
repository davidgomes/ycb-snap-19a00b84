# Upgrade guides

## Upgrading from Canary 1.2.0 to 2.0.0

Canary 2.0.0 introduces `Canary.Hooks` for Phoenix LiveView. `Canary.Plugs` and `Canary.Hooks`
share the same options, so the plug calls can be easily replaced with `mount_canary` calls.

### Update your non-id actions

> Since 2.0.0 the `:persisted` and `:non_id_actions` options are deprecated and will be removed in Canary 2.1.0.
> Canary emits a warning when they are used.

Using a separate `:authorize_resource` call for the actions where there is no resource to load is more explicit.

Let's assume you have the following plug call:

```elixir
plug :load_and_authorize_resource,
  model: Network,
  non_id_actions: [:index, :create, :new],
  preload: [:hypervisor]
```

Now let's break it apart:

```elixir
plug :authorize_resource,
  model: Network,
  only: [:index, :create, :new],
  required: false

plug :load_and_authorize_resource,
  model: Network,
  except: [:index, :create, :new],
  preload: [:hypervisor]
```

1. The non-id actions are authorized with a separate `:authorize_resource` plug. With `required: false` the resource
   is optional and the model module name (`Network`) is used for the `Canada.Can` check - that's how `:non_id_actions` worked.
2. All other actions load and authorize the resource as usual.
3. To load all resources for the `:index` action, add a plug or load them directly in the controller action:

```elixir
# with plug
plug :load_all_networks when action in [:index]

defp load_all_networks(conn, _opts) do
  assign(conn, :networks, Networks.list_networks())
end

# or directly in the controller action
def index(conn, _params) do
  render(conn, "index.html", networks: Networks.list_networks())
end
```

### Replace `:persisted` with `:required`

The `:required` option always loads the resource from the database, even for the `:index`, `:new` and `:create` actions,
and calls the not found handler when the resource is not found.

```elixir
# before
plug :load_and_authorize_resource, model: Post, id_name: "post_id", persisted: true, only: [:create]

# after
plug :load_and_authorize_resource, model: Post, id_name: "post_id", required: true, only: [:create]
```

### `:required` defaults

For `Canary.Hooks` the `:required` option defaults to `true`. When the resource is not found or not assigned,
the socket is halted by the error handler. Set `required: false` for optional resources, then the model module name
is used for the authorization check.

For `Canary.Plugs` the `:required` option defaults to `false` to keep backward compatibility.
