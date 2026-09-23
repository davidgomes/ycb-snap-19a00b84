defmodule GRPC.Client.LoadBalancing.RoundRobin do
  @moduledoc """
  Rotates requests across all connected channels.
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

        :ok = update(state, channels)
        {:ok, state}
    end
  end

  # Channels are stored one row per index so a pick copies a single channel out
  # of ETS. The size is kept in ETS rather than next to the contended cursor to
  # avoid false sharing. Rows and size are inserted atomically and stale rows are
  # deleted afterwards, so every index below the current size is always present.
  @impl true
  def update(%{tid: tid, cursor: cursor}, channels) do
    old_size =
      case :ets.lookup(tid, :size) do
        [{:size, size}] -> size
        [] -> 0
      end

    new_size = length(channels)
    rows = Enum.with_index(channels, fn channel, index -> {index, channel} end)

    :ets.insert(tid, [{:size, new_size} | rows])
    :atomics.put(cursor, 1, 0)

    for index <- new_size..(old_size - 1)//1, do: :ets.delete(tid, index)

    :ok
  end

  @impl true
  def pick(%{tid: tid, cursor: cursor} = state) do
    case :ets.lookup_element(tid, :size, 2) do
      0 ->
        {:error, :no_connection}

      size ->
        index = rem(:atomics.add_get(cursor, 1, 1), size)

        case :ets.lookup(tid, index) do
          [{^index, channel}] -> {:ok, channel}
          # The size shrank after it was read; retry against the new size.
          [] -> pick(state)
        end
    end
  rescue
    # The owning connection may delete the table while a pick is in flight.
    ArgumentError -> {:error, :no_connection}
  end

  @impl true
  def shutdown(%{tid: tid}) do
    :ets.delete(tid)
    :ok
  rescue
    ArgumentError -> :ok
  end
end
