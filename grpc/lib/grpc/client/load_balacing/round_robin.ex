defmodule GRPC.Client.LoadBalancing.RoundRobin do
  @moduledoc """
  Round-robin load balancing: successive picks cycle through the current
  channel list in order.
  """
  @behaviour GRPC.Client.LoadBalancing

  @key :channels

  @impl true
  def init(opts) do
    case Keyword.get(opts, :channels, []) do
      [] ->
        {:error, :no_addresses}

      channels ->
        state = %{
          tid: :ets.new(__MODULE__, [:set, :protected, read_concurrency: true]),
          atomics: :atomics.new(1, signed: false)
        }

        update(state, channels)
    end
  end

  @impl true
  def pick(%{tid: tid, atomics: cursor} = state) do
    case :ets.lookup(tid, @key) do
      [{@key, channels}] when tuple_size(channels) > 0 ->
        # Integer.mod/2 keeps the index valid when the unsigned counter wraps to 0.
        index = Integer.mod(:atomics.add_get(cursor, 1, 1) - 1, tuple_size(channels))
        {:ok, elem(channels, index), state}

      _ ->
        {:error, :no_addresses}
    end
  rescue
    # The table disappears when its owning connection shuts down.
    ArgumentError -> {:error, :no_addresses}
  end

  @impl true
  def update(%{tid: tid, atomics: cursor} = state, channels) do
    :ets.insert(tid, {@key, List.to_tuple(channels)})
    :atomics.put(cursor, 1, 0)
    {:ok, state}
  end
end
