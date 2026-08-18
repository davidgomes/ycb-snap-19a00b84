# Load Balancing

Load balancing is a core capability of modern distributed gRPC systems. Instead of connecting directly to a single static address, the Elixir gRPC client can dynamically resolve multiple backend endpoints using pluggable target schemes (DNS, Unix sockets, xDS, and more). This allows clients to automatically distribute traffic across services and benefit from infrastructure-level routing — whether running on Kubernetes, service meshes like Istio, or traditional on-prem deployments.

The implementation in this library follows the official gRPC Client Load Balancing specification, ensuring compatibility with ecosystem tooling such as Envoy, xDS control planes (see note below), and DNS-based service discovery.

This guide explains how to define target URIs and how the built-in resolver discovers and continuously refreshes backend servers. Once configured, your load-balancing strategy becomes part of the connection string, no additional code required.

## Target Schemes and Resolvers

The `connect/2` function supports URI-like targets that are resolved via the internal **gRPC** [Resolver](lib/grpc/client/resolver.ex).  
You can connect using `DNS`, `Unix Domain sockets`, and `IPv4/IPv6` for now.

### Supported formats:

| Scheme    | Example                     | Description                                  |
|:----------|:----------------------------|:---------------------------------------------|
| `dns://`  | `"dns://example.com:50051"` | Resolves via DNS `A/AAAA` records            |
| `ipv4:`   | `"ipv4:10.0.0.5:50051"`     | Connects directly to an IPv4 address         |
| `unix:`   | `"unix:/tmp/service.sock"`  | Connects via a Unix domain socket            |
| none      | `"127.0.0.1:50051"`         | Implicit DNS (default port `50051`)          |

---

## Examples:

### DNS

```elixir
iex> {:ok, channel} = GRPC.Stub.connect("dns://orders.prod.svc.cluster.local:50051")
iex> request = Orders.GetOrderRequest.new(id: "123")
iex> {:ok, reply} = channel |> Orders.OrderService.Stub.get_order(request)
```

### Unix Domain Sockets

```elixir
iex> {:ok, channel} = GRPC.Stub.connect("unix:/tmp/my.sock")
```

>__Note__: When using `DNS` target, the connection layer periodically refreshes endpoints.

---

## Policies

When a target resolves to more than one address, the client connects to every backend and picks
one of those connections per request. The policy is chosen from the resolved `ServiceConfig`
(`loadBalancingConfig`) when present, otherwise from the `:lb_policy` connect option:

```elixir
iex> {:ok, channel} = GRPC.Stub.connect("dns://orders.prod:50051", lb_policy: :round_robin)
```

| Policy          | Module                                    | Behaviour                                  |
|:----------------|:------------------------------------------|:-------------------------------------------|
| `:pick_first`   | `GRPC.Client.LoadBalancing.PickFirst`     | Always the first healthy backend (default) |
| `:round_robin`  | `GRPC.Client.LoadBalancing.RoundRobin`    | Rotates over the healthy backends          |

Only backends that are currently connected are offered to the policy. Re-resolution reconciles
the connections and hands the new set to the policy, so backends scaling in or out are picked up
without reconnecting the rest.

## Writing a policy

A policy implements `GRPC.Client.LoadBalancing`:

  * `init/1` receives `channels: [GRPC.Channel.t()]` and returns the state to publish.
    It runs in the connection process, so a table created here lives as long as the connection.
  * `pick/1` returns `{:ok, channel}` or `{:error, reason}`. It runs in the calling process on
    every RPC, so it must only read shared state — ETS and `:atomics` are a good fit, a
    `GenServer` call is not.
  * `update/2` receives the connected channels after re-resolution and mutates the state
    published by `init/1` in place. The published state must stay valid, since callers may
    already be holding it.
  * `shutdown/1` frees whatever `init/1` allocated.

---