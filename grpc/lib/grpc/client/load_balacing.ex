defmodule GRPC.Client.LoadBalancing do
  @moduledoc """
  Load balancing behaviour for gRPC clients.

  A load balancer owns the set of ready `GRPC.Channel` structs of a
  `GRPC.Client.Connection` and answers a single question on every RPC:
  which channel should carry it?

  ## Lifecycle

    * `c:init/1` runs once, inside the `GRPC.Client.Connection` process, with
      the channels that connected successfully. Mutable state (ETS tables,
      `:atomics`) must be allocated here so that it is owned by the connection
      process and reclaimed when that process dies.
    * `c:pick/1` runs on the calling process for every RPC. It must be
      lock-free and must not message the connection process.
    * `c:update/2` runs inside the connection process whenever name resolution
      changes the set of ready channels. It mutates the state allocated by
      `c:init/1` in place, so the term handed to `c:pick/1` stays stable for
      the whole life of the connection.
    * `c:stop/1` releases whatever `c:init/1` allocated.

  Since `c:pick/1` may run concurrently with `c:stop/1`, implementations must
  return `{:error, reason}` rather than raise once their state is released.
  """
  alias GRPC.Channel

  @type state :: term()

  @callback init(opts :: keyword()) :: {:ok, state()} | {:error, reason :: any()}

  @callback pick(state()) :: {:ok, Channel.t()} | {:error, reason :: any()}

  @callback update(state(), channels :: [Channel.t()]) :: :ok | {:error, reason :: any()}

  @callback stop(state()) :: :ok
end
