defmodule GRPC.Client.Connection.LBStore do
  @moduledoc false

  # Owns the public ETS table backing GRPC.Client.Connection's load-balancing
  # state. Storing this state in ETS (instead of `:persistent_term`) lets
  # `GRPC.Client.Connection.pick_channel/2` read and update the current LB
  # pick directly from the calling process on every request, without going
  # through the `GRPC.Client.Connection` GenServer and without paying the
  # global-GC cost that frequent `:persistent_term` writes would incur.
  use GenServer

  @table __MODULE__.Table

  @spec table() :: atom()
  def table, do: @table

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
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
