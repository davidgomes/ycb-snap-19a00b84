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

## Load Balancing Policies

When a target resolves to several addresses, the `:lb_policy` option chooses how RPCs are spread across them (a `loadBalancingConfig` in the DNS service config takes precedence):

| Policy                  | Behaviour                                      |
|:------------------------|:-----------------------------------------------|
| `:pick_first` (default) | Sends every RPC to the first connected address |
| `:round_robin`          | Rotates RPCs across all connected addresses    |

```elixir
iex> {:ok, channel} =
...>   GRPC.Stub.connect("dns://orders.prod.svc.cluster.local:50051", lb_policy: :round_robin)
```

The policy picks a channel on every RPC, in the calling process, without messaging the connection process. Addresses that fail to connect are never picked. When re-resolution adds or removes backends, the policy's state is updated in place, so the next RPC already sees the new set.

---