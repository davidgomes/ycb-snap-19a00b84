defmodule GRPC.Client.LoadBalancing do
  @moduledoc """
  Load balancing behaviour for gRPC clients.

  This module defines the behaviour that load balancing strategies must implement.

  `pick/1` is called on every request from the caller's process, so implementations
  must keep their mutable state in shared storage (e.g. ETS or atomics) that is
  safe to read concurrently. `init/1` and `update/2` are called from the
  connection process, which owns any resources the balancer creates.
  """
  @callback init(opts :: keyword()) :: {:ok, state :: any()} | {:error, reason :: any()}

  @callback pick(state :: any()) ::
              {:ok, channel :: GRPC.Channel.t(), new_state :: any()}
              | {:error, reason :: any()}

  @callback update(state :: any(), channels :: [GRPC.Channel.t()]) ::
              {:ok, new_state :: any()} | {:error, reason :: any()}

  @doc """
  Releases any resources held by the balancer state (e.g. ETS tables).
  """
  @callback terminate(state :: any()) :: :ok

  @optional_callbacks terminate: 1
end
