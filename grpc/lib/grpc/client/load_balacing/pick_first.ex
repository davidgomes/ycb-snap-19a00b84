defmodule GRPC.Client.LoadBalancing.PickFirst do
  @moduledoc """
  Load balancing strategy that always picks the first available channel.
  """
  @behaviour GRPC.Client.LoadBalancing

  @impl true
  def init(opts) do
    case Keyword.get(opts, :channels, []) do
      [] ->
        {:error, :no_addresses}

      channels ->
        tid = :ets.new(__MODULE__, [:set, :protected, read_concurrency: true])
        :ok = update(%{tid: tid}, channels)
        {:ok, %{tid: tid}}
    end
  end

  @impl true
  def update(%{tid: tid}, []) do
    :ets.delete(tid, :channel)
    :ok
  end

  def update(%{tid: tid}, [channel | _]) do
    :ets.insert(tid, {:channel, channel})
    :ok
  end

  @impl true
  def pick(%{tid: tid}) do
    case :ets.lookup(tid, :channel) do
      [{:channel, channel}] -> {:ok, channel}
      [] -> {:error, :no_channels}
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
