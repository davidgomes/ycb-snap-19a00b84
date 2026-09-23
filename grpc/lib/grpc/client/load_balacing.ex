defmodule GRPC.Client.LoadBalancing do
  @moduledoc """
  Load balancing behaviour for gRPC clients.

  This module defines the behaviour that load balancing strategies must implement.

  `GRPC.Client.Connection` calls `c:init/1` once, from its own process, and
  publishes the returned state so that `c:pick/1` can run in every caller
  process on every request, without going through the connection process.
  Because the published state is never republished, implementations must
  keep anything that changes (the channel list, cursors, counters) in
  storage shared by reference, such as ETS tables owned by the calling
  process or `:atomics`, and `c:update/2` must mutate that storage in place.
  """
  alias GRPC.Channel

  @doc """
  Builds the balancer state from the `:channels` option, a list of connected
  `GRPC.Channel` structs in resolver order.
  """
  @callback init(opts :: keyword()) :: {:ok, state :: any()} | {:error, reason :: any()}

  @doc """
  Picks the channel to use for one request. Called concurrently from many
  processes; the returned state is discarded by `GRPC.Client.Connection`.
  """
  @callback pick(state :: any()) ::
              {:ok, Channel.t(), new_state :: any()}
              | {:error, reason :: any()}

  @doc """
  Replaces the channel list after name re-resolution. An empty list is valid
  and makes subsequent picks fail until healthy channels are available again.
  """
  @callback update(state :: any(), channels :: [Channel.t()]) ::
              {:ok, new_state :: any()} | {:error, reason :: any()}
end
