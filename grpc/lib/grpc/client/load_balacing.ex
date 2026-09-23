defmodule GRPC.Client.LoadBalancing do
  @moduledoc """
  Load balancing behaviour for gRPC clients.

  This module defines the behaviour that load balancing strategies must implement.

  `c:init/1`, `c:update/2` and `c:shutdown/1` run inside the owning
  `GRPC.Client.Connection` process, while `c:pick/1` runs in the caller of every RPC.
  The state returned by `c:init/1` is published once and never republished, so
  `c:update/2` must mutate shared storage (e.g. ETS or `:atomics`) in place and
  `c:pick/1` must be safe to call concurrently from any process, including after
  `c:shutdown/1` has run.
  """
  alias GRPC.Channel

  @doc """
  Initializes the strategy. `opts` contains `:channels`, the connected channels
  in resolver order.
  """
  @callback init(opts :: keyword()) :: {:ok, state :: any()} | {:error, reason :: any()}

  @doc """
  Replaces the set of connected channels after re-resolution. May be empty.
  """
  @callback update(state :: any(), channels :: [Channel.t()]) :: :ok

  @callback pick(state :: any()) :: {:ok, Channel.t()} | {:error, reason :: any()}

  @callback shutdown(state :: any()) :: :ok
end
