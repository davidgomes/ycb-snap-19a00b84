# Upgrade guides

## Upgrading from Canary 1.2.0 to 2.0.0

### The `:required` option is enabled by default

Since 2.0.0 `Canary.Plugs` and `Canary.Hooks` share the same API, and the `:required` option defaults to `true`.
When the resource cannot be loaded the `not_found_handler` is called.

If the resource is optional, set `required: false`:

```elixir
plug :load_resource,
  model: Post,
  required: false
```

When the resource is not required and it's not available in assigns, `authorize_resource` uses the model module name
as the resource for the call to `Canada.can?`.

### Update your non-id actions

> Since 2.0.0 the `:persisted` and `:non_id_actions` options are deprecated and will be removed in Canary 2.1.0.

Using `:authorize_resource` for actions where there is no resource to load is more explicit.

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

1. The non-id actions are authorized by a separate plug. The `required: false` option marks the resource as optional, so the model module name is used for the authorization check - that's essentially how `:non_id_actions` worked.
2. For the other actions it loads and authorizes the resource as usual.
3. To load all resources on the `:index` action you can set up a plug, or load them directly in `index/2`:

```elixir
# with plug

plug :load_all_networks when action in [:index]

defp load_all_networks(conn, _opts) do
  assign(conn, :networks, Hypervisors.list_hypervisor_networks(conn.assigns.hypervisor))
end

# or directly in the controller action

def index(conn, _params) do
  networks = Hypervisors.list_hypervisor_networks(conn.assigns.hypervisor)
  render(conn, "index.html", networks: networks)
end
```

### Remove the `:persisted` option

With the [updated non-id actions](#update-your-non-id-actions) the `:persisted` option is no longer needed.
Replace `persisted: true` with `required: true` to always load a single resource from the database, e.g. a parent of a nested resource.
