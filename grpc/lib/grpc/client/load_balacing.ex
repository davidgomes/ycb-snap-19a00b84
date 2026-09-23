defmodule GRPC.Client.LoadBalancing do
  @moduledoc """
  Load balancing behaviour for gRPC clients.

  This module defines the behaviour that load balancing strategies must implement.

  `init/1`, `update/2` and `shutdown/1` are invoked by the `GRPC.Client.Connection`
  process, which owns any resources (such as ETS tables) created by the strategy.

  `pick/1` is invoked on every RPC from the caller process, so it must not rely on
  the connection process being available and must be safe to call concurrently.
  Strategies typically keep their state in a `:public` or `:protected` ETS table and
  pass the table reference around as the state.
  """
  alias GRPC.Channel

  @doc """
  Initializes the strategy with the currently connected channels.

  Receives the `:channels` option, a list of connected `GRPC.Channel` structs in
  resolution order.
  """
  @callback init(opts :: keyword()) :: {:ok, state :: any()} | {:error, reason :: any()}

  @doc """
  Picks a channel for a single request. Called from the caller process.
  """
  @callback pick(state :: any()) :: {:ok, Channel.t()} | {:error, reason :: any()}

  @doc """
  Replaces the set of connected channels, e.g. after re-resolution.

  The list may be empty, in which case subsequent picks should return an error.
  """
  @callback update(state :: any(), channels :: [Channel.t()]) :: {:ok, new_state :: any()}

  @doc """
  Releases any resources held by the strategy.
  """
  @callback shutdown(state :: any()) :: :ok
end
