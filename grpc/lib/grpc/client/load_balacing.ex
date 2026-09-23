defmodule GRPC.Client.LoadBalancing do
  @moduledoc """
  Load balancing behaviour for gRPC clients.

  This module defines the behaviour that load balancing strategies must implement.

  `init/1` and `update/2` are invoked by the connection process whenever the set
  of connected channels changes. `pick/1` is invoked on every request, directly
  from the calling process, so it must be safe to call concurrently and must not
  rely on messaging the connection process. State that needs to change on pick
  (e.g. a round-robin cursor) should live in ETS tables created in `init/1`,
  which are then owned by the connection process.
  """
  alias GRPC.Channel

  @callback init(opts :: keyword()) :: {:ok, state :: any()} | {:error, reason :: any()}

  @callback update(state :: any(), channels :: [Channel.t()]) ::
              {:ok, new_state :: any()} | {:error, reason :: any()}

  @callback pick(state :: any()) :: {:ok, Channel.t()} | {:error, reason :: any()}
end
