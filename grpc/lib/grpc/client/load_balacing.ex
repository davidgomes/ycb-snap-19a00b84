defmodule GRPC.Client.LoadBalancing do
  @moduledoc """
  Load balancing behaviour for gRPC clients.

  This module defines the behaviour that load balancing strategies must implement.

  A policy owns the state used to route requests. `init/1` and `update/2` run in the
  owning `GRPC.Client.Connection` process, so a table created by `init/1` lives exactly
  as long as the connection. `pick/1` runs in the calling process on every RPC and must
  therefore be read-only and lock-free.
  """
  @type channel :: GRPC.Channel.t()

  @callback init(opts :: keyword()) :: {:ok, state :: any()} | {:error, reason :: any()}

  @callback pick(state :: any()) :: {:ok, channel()} | {:error, reason :: any()}

  @callback update(state :: any(), channels :: [channel()]) :: :ok

  @callback shutdown(state :: any()) :: :ok
end
