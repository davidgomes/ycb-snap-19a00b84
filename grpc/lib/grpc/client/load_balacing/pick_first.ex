defmodule GRPC.Client.LoadBalancing.PickFirst do
  @moduledoc """
  Sends every request to the first available channel.

  The channel set lives in an ETS table owned by the `GRPC.Client.Connection`
  process, so `pick/1` is a single lock-free read.
  """
  @behaviour GRPC.Client.LoadBalancing

  @impl true
  def init(opts) do
    channels = Keyword.get(opts, :channels, [])

    table = :ets.new(:grpc_lb_pick_first, [:set, :protected, read_concurrency: true])
    :ets.insert(table, {:channels, List.to_tuple(channels)})

    {:ok, %{table: table}}
  end

  @impl true
  def pick(%{table: table}) do
    case :ets.lookup(table, :channels) do
      [{:channels, channels}] when tuple_size(channels) > 0 ->
        {:ok, elem(channels, 0)}

      _empty_or_missing ->
        {:error, :no_channels}
    end
  rescue
    # `shutdown/1` may delete the table while a pick is in flight.
    ArgumentError -> {:error, :no_channels}
  end

  @impl true
  def update(%{table: table}, channels) do
    :ets.insert(table, {:channels, List.to_tuple(channels)})
    :ok
  end

  @impl true
  def shutdown(%{table: table}) do
    :ets.delete(table)
    :ok
  rescue
    ArgumentError -> :ok
  end
end
