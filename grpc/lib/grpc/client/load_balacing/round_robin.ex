defmodule GRPC.Client.LoadBalancing.RoundRobin do
  @moduledoc """
  Rotates over the available channels, one step per request.

  The channel set lives in an ETS table owned by the `GRPC.Client.Connection`
  process and the cursor is an `:atomics` counter, so concurrent picks rotate
  without a lock and without going through the connection process.
  """
  @behaviour GRPC.Client.LoadBalancing

  @impl true
  def init(opts) do
    channels = Keyword.get(opts, :channels, [])

    table = :ets.new(:grpc_lb_round_robin, [:set, :protected, read_concurrency: true])
    :ets.insert(table, {:channels, List.to_tuple(channels)})

    {:ok, %{table: table, cursor: :atomics.new(1, signed: false)}}
  end

  @impl true
  def pick(%{table: table, cursor: cursor}) do
    case :ets.lookup(table, :channels) do
      [{:channels, channels}] when tuple_size(channels) > 0 ->
        {:ok, elem(channels, next_index(cursor, tuple_size(channels)))}

      _empty_or_missing ->
        {:error, :no_channels}
    end
  rescue
    # `shutdown/1` may delete the table while a pick is in flight.
    ArgumentError -> {:error, :no_channels}
  end

  @impl true
  def update(%{table: table, cursor: cursor}, channels) do
    :ets.insert(table, {:channels, List.to_tuple(channels)})
    :atomics.put(cursor, 1, 0)
    :ok
  end

  @impl true
  def shutdown(%{table: table}) do
    :ets.delete(table)
    :ok
  rescue
    ArgumentError -> :ok
  end

  # The counter is only ever incremented, so the pre-increment value is the one to
  # rotate on. Adding `count` keeps the index in range when the unsigned counter
  # wraps back to 0.
  defp next_index(cursor, count) do
    rem(:atomics.add_get(cursor, 1, 1) - 1 + count, count)
  end
end
