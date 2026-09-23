# Upgrade guides

## Upgrading from Canary 1.2.0 to 2.0.0

`Canary.Plugs` and `Canary.Hooks` now share the same API and accept the same options.

### `:required` defaults to `true`

The `:required` option now defaults to `true` for both plugs and hooks. When the resource
cannot be loaded, the not found handler is called. For authorization, a missing resource
means the action is unauthorized.

If a resource is optional, pass `required: false` explicitly. The model module name will then be
used in the `Canada.Can` implementation when the resource is not loaded.

### Update your non-id actions

> Since 2.0.0 the `:persisted` and `:non_id_actions` options are deprecated and will be removed in Canary 2.1.0.

You need to update plug calls. Using `:authorize_resource` for actions where there is no actual load action is more explicit.

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

1. For the non-id actions there is a separate plug for authorization. The `required: false` option marks the resource as optional when doing the authorization check, so the model module name is used. This is essentially how `:non_id_actions` worked.
2. For actions other than `:index`, `:create` and `:new` it will load and authorize resources as usual.
3. To load all resources on the `:index` action you can set up a plug, or load them directly in `index/2`:

```elixir
# with plug

plug :load_all_resources when action in [:index]

defp load_all_resources(conn, _opts) do
  assign(conn, :networks, Hypervisors.list_hypervisor_networks(hypervisor))
end

# or directly in the controller action

def index(conn, _params) do
  networks = Hypervisors.list_hypervisor_networks(hypervisor)
  render(conn, "index.html", networks: networks)
end
```

### Remove the `:persisted` option

With the [updated non-id actions](#update-your-non-id-actions) the `:persisted` option is no longer required.
