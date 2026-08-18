defmodule GRPC.Client.LoadBalancing.PickFirst do
  @moduledoc """
  Sends every RPC to the first ready channel.

  The channel set lives in an ETS table owned by the
  `GRPC.Client.Connection` process, so `pick/1` is a single lock-free read
  from the caller process and re-resolution only rewrites one ETS row.
  """
  @behaviour GRPC.Client.LoadBalancing

  @channels_key :channels

  @impl true
  def init(opts) do
    case Keyword.get(opts, :channels, []) do
      [] ->
        {:error, :no_channels}

      channels ->
        table = :ets.new(:grpc_lb_pick_first, [:set, :protected, read_concurrency: true])
        :ets.insert(table, {@channels_key, List.to_tuple(channels)})

        {:ok, %{table: table}}
    end
  end

  @impl true
  def pick(%{table: table}) do
    case :ets.lookup_element(table, @channels_key, 2) do
      {} -> {:error, :no_connection}
      channels -> {:ok, elem(channels, 0)}
    end
  rescue
    # disconnect/1 may drop the table while a pick is in flight
    ArgumentError -> {:error, :no_connection}
  end

  @impl true
  def update(%{table: table}, channels) do
    :ets.insert(table, {@channels_key, List.to_tuple(channels)})
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
