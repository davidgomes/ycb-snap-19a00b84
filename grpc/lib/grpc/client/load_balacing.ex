defmodule GRPC.Client.LoadBalancing do
  @moduledoc """
  Load balancing behaviour for gRPC clients.

  This module defines the behaviour that load balancing strategies must implement.

  The state returned by `c:init/1` is owned by the connection process that
  called it, but `c:pick/1` is invoked on every request from arbitrary caller
  processes. Implementations must therefore keep any mutable data in storage
  that can be read and updated concurrently (e.g. a public ETS table) instead
  of returning an updated state from `c:pick/1`.
  """
  alias GRPC.Channel

  @type state :: term()

  @doc """
  Initializes the balancer. Receives the connected channels in `:channels`.
  """
  @callback init(opts :: keyword()) :: {:ok, state()} | {:error, reason :: any()}

  @doc """
  Picks a channel for a single request. Must be safe to call concurrently.
  """
  @callback pick(state()) :: {:ok, Channel.t()} | {:error, reason :: any()}

  @doc """
  Replaces the set of channels the balancer picks from.
  """
  @callback update(state(), channels :: [Channel.t()]) :: :ok

  @doc """
  Releases any resources held by the balancer.
  """
  @callback shutdown(state()) :: :ok
end
