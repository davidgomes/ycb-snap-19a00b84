defmodule GRPC.Client.LoadBalancing.PickFirst do
  @moduledoc """
  Load balancing strategy that sends every RPC to the first connected channel.
  """
  @behaviour GRPC.Client.LoadBalancing

  @impl true
  def init(opts) do
    case Keyword.get(opts, :channels, []) do
      [] ->
        {:error, :no_addresses}

      channels ->
        tid = :ets.new(__MODULE__, [:set, :protected, read_concurrency: true])
        update(%{tid: tid}, channels)
    end
  end

  @impl true
  def pick(%{tid: tid}) do
    case :ets.lookup(tid, :channel) do
      [{:channel, channel}] -> {:ok, channel}
      [] -> {:error, :no_addresses}
    end
  rescue
    # The table is deleted by shutdown/1 while picks may still be in flight.
    ArgumentError -> {:error, :no_connection}
  end

  @impl true
  def update(%{tid: tid} = state, channels) do
    case channels do
      [first | _] -> :ets.insert(tid, {:channel, first})
      [] -> :ets.delete(tid, :channel)
    end

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
