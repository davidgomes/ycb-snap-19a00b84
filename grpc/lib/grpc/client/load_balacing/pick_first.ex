defmodule GRPC.Client.LoadBalancing.PickFirst do
  @moduledoc """
  Sends every request to the first connected channel.

  The selected channel is stored in an ETS table owned by the connection process,
  so picks are a single ETS read in the caller process.
  """
  @behaviour GRPC.Client.LoadBalancing

  @impl true
  def init(opts) do
    case Keyword.get(opts, :channels, []) do
      [] ->
        {:error, :no_channels}

      channels ->
        tid = :ets.new(__MODULE__, [:set, :protected, read_concurrency: true])
        put_current(tid, channels)
        {:ok, %{tid: tid}}
    end
  end

  @impl true
  def pick(%{tid: tid}) do
    case :ets.lookup_element(tid, :current, 2) do
      nil -> {:error, :no_channels}
      channel -> {:ok, channel}
    end
  end

  @impl true
  def update(%{tid: tid} = state, channels) do
    put_current(tid, channels)
    {:ok, state}
  end

  @impl true
  def shutdown(%{tid: tid}) do
    :ets.delete(tid)
    :ok
  rescue
    ArgumentError -> :ok
  end

  defp put_current(tid, channels) do
    :ets.insert(tid, {:current, List.first(channels)})
  end
end
