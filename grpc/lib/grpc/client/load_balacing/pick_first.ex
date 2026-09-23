defmodule GRPC.Client.LoadBalancing.PickFirst do
  @behaviour GRPC.Client.LoadBalancing

  @channel_key :channel

  @impl true
  def init(opts) do
    case Keyword.get(opts, :channels, []) do
      [] ->
        {:error, :no_addresses}

      [channel | _] ->
        tid = :ets.new(:grpc_lb_pick_first, [:set, :public, read_concurrency: true])
        :ets.insert(tid, {@channel_key, channel})
        {:ok, %{tid: tid}}
    end
  end

  @impl true
  def pick(%{tid: tid} = state) do
    case :ets.lookup(tid, @channel_key) do
      [{@channel_key, channel}] -> {:ok, channel, state}
      [] -> {:error, :no_addresses}
    end
  rescue
    ArgumentError -> {:error, :no_addresses}
  end

  @impl true
  def update(%{tid: tid} = state, []) do
    :ets.delete(tid, @channel_key)
    {:ok, state}
  end

  def update(%{tid: tid} = state, [channel | _]) do
    :ets.insert(tid, {@channel_key, channel})
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
