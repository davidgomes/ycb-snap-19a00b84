# Upgrade guides

## Upgrading from Canary 1.2.0 to 2.0.0

`Canary.Plugs` and `Canary.Hooks` now share the same API, so the same opts can be used with `plug` and `mount_canary`.

### The `:required` option defaults to `true`

When the resource cannot be loaded, the not found handler is called by default. If a missing resource is expected, set `required: false`:

```elixir
  plug :load_resource,
    model: Post,
    required: false
```

For the authorization check, `required: false` also means that the model module name is used as the resource when the resource is not available.

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

1. For the non-id actions there is a separate plug for authorization. The `required: false` option marks the resource as optional when doing the authorization check, so the model module name is used. Essentially, that's how `:non_id_actions` worked.
2. For actions other than `:index`, `:create` and `:new` it will load and authorize resources as usual.
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

With the [updated non-id actions](#update-your-non-id-actions) the `:persisted` option is no longer needed. To always load a single resource from the database, for example for nested resources, set `required: true` explicitly.
