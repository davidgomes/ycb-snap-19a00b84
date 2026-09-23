defmodule GRPC.Client.LoadBalancing.PickFirst do
  @moduledoc """
  Pick-first load balancing: every pick returns the first channel of the
  current channel list.
  """
  @behaviour GRPC.Client.LoadBalancing

  alias GRPC.Channel

  @key :current

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
  def pick(%{tid: tid} = state) do
    case :ets.lookup(tid, @key) do
      [{@key, %Channel{} = channel}] -> {:ok, channel, state}
      _ -> {:error, :no_addresses}
    end
  rescue
    # The table disappears when its owning connection shuts down.
    ArgumentError -> {:error, :no_addresses}
  end

  @impl true
  def update(%{tid: tid} = state, channels) do
    :ets.insert(tid, {@key, List.first(channels)})
    {:ok, state}
  end
end
