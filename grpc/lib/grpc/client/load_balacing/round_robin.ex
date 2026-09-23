defmodule GRPC.Client.LoadBalancing.RoundRobin do
  @behaviour GRPC.Client.LoadBalancing

  @max_index 0xFFFFFFFF

  @impl true
  def init(opts) do
    case Keyword.get(opts, :channels, []) do
      [] ->
        {:error, :no_channels}

      channels ->
        table = :ets.new(__MODULE__, [:set, :public, read_concurrency: true])
        :ets.insert(table, [{:channels, List.to_tuple(channels)}, {:index, -1}])
        {:ok, %{table: table}}
    end
  end

  @impl true
  def update(%{table: table} = state, channels) do
    :ets.insert(table, {:channels, List.to_tuple(channels)})
    {:ok, state}
  end

  @impl true
  def pick(%{table: table}) do
    case :ets.lookup(table, :channels) do
      [{:channels, {}}] ->
        {:error, :no_channels}

      [{:channels, channels}] ->
        index = :ets.update_counter(table, :index, {2, 1, @max_index, 0})
        {:ok, elem(channels, rem(index, tuple_size(channels)))}
    end
  end
end
