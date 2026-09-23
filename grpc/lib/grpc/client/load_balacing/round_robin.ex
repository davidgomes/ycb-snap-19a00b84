defmodule GRPC.Client.LoadBalancing.RoundRobin do
  @moduledoc """
  Load balancing strategy that rotates RPCs across all connected channels.
  """
  @behaviour GRPC.Client.LoadBalancing

  @impl true
  def init(opts) do
    case Keyword.get(opts, :channels, []) do
      [] ->
        {:error, :no_addresses}

      channels ->
        state = %{
          tid: :ets.new(__MODULE__, [:set, :protected, read_concurrency: true]),
          cursor: :atomics.new(1, signed: false)
        }

        update(state, channels)
    end
  end

  @impl true
  def pick(%{tid: tid, cursor: cursor}) do
    case :ets.lookup(tid, :channels) do
      [{:channels, channels}] when tuple_size(channels) > 0 ->
        n = :atomics.add_get(cursor, 1, 1)
        {:ok, elem(channels, rem(n - 1, tuple_size(channels)))}

      _ ->
        {:error, :no_addresses}
    end
  rescue
    # The table is deleted by shutdown/1 while picks may still be in flight.
    ArgumentError -> {:error, :no_connection}
  end

  @impl true
  def update(%{tid: tid, cursor: cursor} = state, channels) do
    :ets.insert(tid, {:channels, List.to_tuple(channels)})
    :atomics.put(cursor, 1, 0)
    {:ok, state}
  end

  @impl true
  def shutdown(%{tid: tid}) do
    :ets.delete(tid)
    :ok
  rescue
    ArgumentError -> :ok
  end
end
