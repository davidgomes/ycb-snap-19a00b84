defmodule GRPC.Client.LoadBalancing.PickFirst do
  @behaviour GRPC.Client.LoadBalancing

  @current_key :current

  @impl true
  def init(opts) do
    case Keyword.get(opts, :channels, []) do
      [] ->
        {:error, :no_addresses}

      [first | _] ->
        tid = :ets.new(:grpc_lb_pick_first, [:set, :public, read_concurrency: true])
        :ets.insert(tid, {@current_key, first})
        {:ok, %{tid: tid}}
    end
  end

  @impl true
  def pick(%{tid: tid} = state) do
    case :ets.lookup(tid, @current_key) do
      [{@current_key, nil}] -> {:error, :no_addresses}
      [{@current_key, channel}] -> {:ok, channel, state}
      [] -> {:error, :no_addresses}
    end
  rescue
    ArgumentError -> {:error, :no_addresses}
  end

  @impl true
  def update(%{tid: tid} = state, channels) do
    :ets.insert(tid, {@current_key, List.first(channels)})
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
