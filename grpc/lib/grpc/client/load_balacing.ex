defmodule GRPC.Client.LoadBalancing do
  @moduledoc """
  Load balancing behaviour for gRPC clients.

  This module defines the behaviour that load balancing strategies must implement.

  The state returned by `c:init/1` is published once per connection and then
  read concurrently by every process that issues an RPC, so `c:pick/1` is
  called from caller processes, not from the connection process. Strategies
  should therefore keep their mutable data in shared storage (e.g. ETS or
  `:atomics`) and have `c:update/2` modify it in place, returning the same
  state term.
  """

  @callback init(opts :: keyword()) :: {:ok, state :: any()} | {:error, reason :: any()}

  @callback pick(state :: any()) ::
              {:ok, GRPC.Channel.t(), new_state :: any()} | {:error, reason :: any()}

  @callback update(state :: any(), channels :: [GRPC.Channel.t()]) ::
              {:ok, new_state :: any()} | {:error, reason :: any()}

  @doc """
  Releases any resources held by the balancer state (e.g. ETS tables).
  """
  @callback terminate(state :: any()) :: :ok

  @optional_callbacks terminate: 1
end
