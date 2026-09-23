defmodule GRPC.Client.LoadBalancing do
  @moduledoc """
  Load balancing behaviour for gRPC clients.

  This module defines the behaviour that load balancing strategies must implement.

  `init/1`, `update/2` and `shutdown/1` are invoked by the connection process,
  which owns any resources (e.g. ETS tables) the strategy creates. `pick/1` is
  invoked on every RPC from the caller's process, so it must be safe to call
  concurrently and must not rely on messaging the connection process.

  The state returned by `init/1` is published once for the lifetime of the
  connection, so `update/2` must apply changes in place (e.g. by writing to
  ETS or atomics) rather than returning a new state.
  """
  alias GRPC.Channel

  @callback init(opts :: keyword()) :: {:ok, state :: any()} | {:error, reason :: any()}

  @callback update(state :: any(), channels :: [Channel.t()]) :: :ok | {:error, reason :: any()}

  @callback pick(state :: any()) :: {:ok, Channel.t()} | {:error, reason :: any()}

  @callback shutdown(state :: any()) :: :ok
end
