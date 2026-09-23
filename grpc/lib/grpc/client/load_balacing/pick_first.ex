defmodule GRPC.Client.LoadBalancing.PickFirst do
  @behaviour GRPC.Client.LoadBalancing

  @impl true
  def init(opts) do
    tid = :ets.new(__MODULE__, [:set, :public, read_concurrency: true])
    state = %{tid: tid}
    :ok = update(state, Keyword.get(opts, :channels, []))
    {:ok, state}
  end

  @impl true
  def pick(%{tid: tid}) do
    case :ets.lookup(tid, :channel) do
      [{:channel, channel}] -> {:ok, channel}
      [] -> {:error, :no_channels}
    end
  end

  @impl true
  def update(%{tid: tid}, [channel | _]) do
    :ets.insert(tid, {:channel, channel})
    :ok
  end

  def update(%{tid: tid}, []) do
    :ets.delete(tid, :channel)
    :ok
  end

  @impl true
  def shutdown(%{tid: tid}) do
    :ets.delete(tid)
    :ok
  rescue
    ArgumentError -> :ok
  end
end
