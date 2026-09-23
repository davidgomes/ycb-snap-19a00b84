defmodule GRPC.Client.LoadBalancing.RoundRobin do
  @behaviour GRPC.Client.LoadBalancing

  @channels_key :channels

  @impl true
  def init(opts) do
    case Keyword.get(opts, :channels, []) do
      [] ->
        {:error, :no_addresses}

      channels ->
        tid = :ets.new(:grpc_lb_round_robin, [:set, :public, read_concurrency: true])
        counter = :atomics.new(1, signed: false)
        :ets.insert(tid, {@channels_key, List.to_tuple(channels)})
        {:ok, %{tid: tid, counter: counter}}
    end
  end

  @impl true
  def pick(%{tid: tid, counter: counter} = state) do
    case :ets.lookup(tid, @channels_key) do
      [{@channels_key, channels}] when tuple_size(channels) > 0 ->
        idx = :atomics.add_get(counter, 1, 1)
        {:ok, elem(channels, Integer.mod(idx - 1, tuple_size(channels))), state}

      _ ->
        {:error, :no_addresses}
    end
  rescue
    ArgumentError -> {:error, :no_addresses}
  end

  @impl true
  def update(%{tid: tid, counter: counter} = state, channels) do
    :ets.insert(tid, {@channels_key, List.to_tuple(channels)})
    :atomics.put(counter, 1, 0)
    {:ok, state}
  end

  @impl true
  def terminate(%{tid: tid}) do
    :ets.delete(tid)
    :ok
  rescue
    ArgumentError -> :ok
  end
end
