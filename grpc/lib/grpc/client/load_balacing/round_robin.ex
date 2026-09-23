defmodule GRPC.Client.LoadBalancing.RoundRobin do
  @moduledoc """
  Round-robin load balancing across all connected channels.

  Channels are stored in an ETS table owned by the connection process. Each pick
  atomically increments a shared counter in the same table, so requests issued
  concurrently from different processes are spread evenly without going through
  the connection process.
  """
  @behaviour GRPC.Client.LoadBalancing

  # Keeps the counter a small integer; wrapping only skews one pick per wrap.
  @max_index 0xFFFFFFFF

  @impl true
  def init(opts) do
    case Keyword.get(opts, :channels, []) do
      [] ->
        {:error, :no_channels}

      channels ->
        tid =
          :ets.new(__MODULE__, [:set, :public, read_concurrency: true, write_concurrency: true])

        :ets.insert(tid, [{:index, -1}, {:channels, List.to_tuple(channels)}])
        {:ok, %{tid: tid}}
    end
  end

  @impl true
  def pick(%{tid: tid}) do
    case :ets.lookup_element(tid, :channels, 2) do
      {} ->
        {:error, :no_channels}

      channels ->
        index = :ets.update_counter(tid, :index, {2, 1, @max_index, 0})
        {:ok, elem(channels, rem(index, tuple_size(channels)))}
    end
  end

  @impl true
  def update(%{tid: tid} = state, channels) do
    :ets.insert(tid, {:channels, List.to_tuple(channels)})
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
