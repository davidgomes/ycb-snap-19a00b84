defmodule GRPC.Client.LoadBalancing.PickFirst do
  @moduledoc """
  Sends every request to the first connected channel.
  """
  @behaviour GRPC.Client.LoadBalancing

  @impl true
  def init(opts) do
    case Keyword.get(opts, :channels, []) do
      [] ->
        {:error, :no_addresses}

      channels ->
        state = %{tid: :ets.new(__MODULE__, [:set, :protected, read_concurrency: true])}
        :ok = update(state, channels)
        {:ok, state}
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
  def pick(%{tid: tid}) do
    case :ets.lookup(tid, :channel) do
      [{:channel, channel}] -> {:ok, channel}
      [] -> {:error, :no_connection}
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
