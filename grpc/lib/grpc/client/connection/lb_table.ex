defmodule GRPC.Client.Connection.LBTable do
  @moduledoc false

  # Owns the public, named ETS table backing load-balancing state for
  # `GRPC.Client.Connection`. The table survives for the lifetime of the
  # `:grpc` application so `pick_channel/2` can read/update LB state directly
  # from any process without going through a `Connection` GenServer call.

  use GenServer

  @table __MODULE__

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    :ets.new(@table, [
      :set,
      :public,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])

    {:ok, %{}}
  end
end
