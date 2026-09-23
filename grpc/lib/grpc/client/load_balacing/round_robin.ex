defmodule GRPC.Client.LoadBalancing.RoundRobin do
  @moduledoc """
  Load balancing strategy that rotates through the available channels on
  every pick.
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
          counter: :atomics.new(1, signed: false)
        }

        :ok = update(state, channels)
        {:ok, state}
    end
  end

  @impl true
  def update(%{tid: tid, counter: counter}, channels) do
    :ets.insert(tid, {:channels, List.to_tuple(channels)})
    :atomics.put(counter, 1, 0)
    :ok
  end

  @impl true
  def pick(%{tid: tid, counter: counter}) do
    case :ets.lookup(tid, :channels) do
      [{:channels, {}}] ->
        {:error, :no_channels}

      [{:channels, channels}] ->
        size = tuple_size(channels)
        # add_get wraps to 0 on overflow, so offset instead of subtracting 1
        index = rem(:atomics.add_get(counter, 1, 1) + size - 1, size)
        {:ok, elem(channels, index)}

      [] ->
        {:error, :no_channels}
    end
  rescue
    # the table is deleted by shutdown/1 on disconnect, possibly mid-pick
    ArgumentError -> {:error, :no_channels}
  end

  @impl true
  def shutdown(%{tid: tid}) do
    :ets.delete(tid)
    :ok
  rescue
    ArgumentError -> :ok
  end
end
