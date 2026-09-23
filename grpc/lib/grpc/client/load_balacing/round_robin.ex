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
    case :ets.lookup_element(tid, :channels, 2) do
      {} ->
        {:error, :no_connection}

      channels ->
        index = rem(:atomics.add_get(counter, 1, 1), tuple_size(channels))
        {:ok, elem(channels, index)}
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
