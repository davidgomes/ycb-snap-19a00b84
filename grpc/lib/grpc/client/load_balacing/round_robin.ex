defmodule GRPC.Client.LoadBalancing.RoundRobin do
  @moduledoc """
  Rotates over the ready channels, one step per RPC.

  The channel set lives in an ETS table owned by the
  `GRPC.Client.Connection` process and the cursor is an `:atomics` counter,
  so `pick/1` rotates from the caller process without a lock and without a
  message to the connection. Re-resolution rewrites the ETS row and rewinds
  the cursor in place.
  """
  @behaviour GRPC.Client.LoadBalancing

  @channels_key :channels
  @cursor_index 1

  @impl true
  def init(opts) do
    case Keyword.get(opts, :channels, []) do
      [] ->
        {:error, :no_channels}

      channels ->
        table = :ets.new(:grpc_lb_round_robin, [:set, :protected, read_concurrency: true])
        :ets.insert(table, {@channels_key, List.to_tuple(channels)})

        {:ok, %{table: table, cursor: :atomics.new(1, signed: false)}}
    end
  end

  @impl true
  def pick(%{table: table, cursor: cursor}) do
    case :ets.lookup_element(table, @channels_key, 2) do
      {} ->
        {:error, :no_connection}

      channels ->
        index = rem(:atomics.add_get(cursor, @cursor_index, 1) - 1, tuple_size(channels))
        {:ok, elem(channels, index)}
    end
  rescue
    # disconnect/1 may drop the table while a pick is in flight
    ArgumentError -> {:error, :no_connection}
  end

  @impl true
  def update(%{table: table, cursor: cursor}, channels) do
    :ets.insert(table, {@channels_key, List.to_tuple(channels)})
    :atomics.put(cursor, @cursor_index, 0)
    :ok
  rescue
    ArgumentError -> {:error, :no_connection}
  end

  @impl true
  def stop(%{table: table}) do
    :ets.delete(table)
    :ok
  rescue
    ArgumentError -> :ok
  end
end
