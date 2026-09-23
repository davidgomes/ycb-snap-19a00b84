defmodule GRPC.Client.LoadBalancing do
  @moduledoc """
  Load balancing behaviour for gRPC clients.

  This module defines the behaviour that load balancing strategies must implement.

  The connection process initializes the strategy with its connected channels and
  publishes the resulting state once. `c:pick/1` then runs on every RPC in the
  caller's process, concurrently and without going through the connection process,
  so it must be cheap and must not rely on process-local state. Anything that
  changes over the life of the connection (the channel set, cursors, weights)
  should live in shared storage such as ETS or `:atomics`, so that `c:update/2`
  can mutate it in place and picks observe the change immediately.
  """

  alias GRPC.Channel

  @doc """
  Initializes the strategy.

  Called from the connection process, which owns any ETS tables created here.

  Options:

    * `:channels` – the connected `GRPC.Channel` structs, in resolver order.
      Returns `{:error, :no_addresses}` when empty.
  """
  @callback init(opts :: keyword()) :: {:ok, state :: any()} | {:error, reason :: any()}

  @doc """
  Picks the channel for a single RPC.
  """
  @callback pick(state :: any()) :: {:ok, Channel.t()} | {:error, reason :: any()}

  @doc """
  Replaces the set of connected channels after re-resolution.

  `channels` may be empty, in which case `c:pick/1` must return an error until a
  later update provides channels again. Returning a state that differs from the
  given one forces the connection to republish it to `:persistent_term`, which
  triggers a node-wide garbage collection pass, so strategies should mutate their
  shared storage in place and return the same state.
  """
  @callback update(state :: any(), channels :: [Channel.t()]) ::
              {:ok, new_state :: any()} | {:error, reason :: any()}

  @doc """
  Releases the resources held by the strategy. Must be idempotent.
  """
  @callback shutdown(state :: any()) :: :ok
end
