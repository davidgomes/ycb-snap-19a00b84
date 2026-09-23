defmodule GRPC.Client.LoadBalancing.RoundRobin do
  @behaviour GRPC.Client.LoadBalancing

  @impl true
  def init(opts) do
    tid =
      :ets.new(__MODULE__, [:set, :public, read_concurrency: true, write_concurrency: true])

    :ets.insert(tid, {:index, -1})
    state = %{tid: tid}
    :ok = update(state, Keyword.get(opts, :channels, []))
    {:ok, state}
  end

  @impl true
  def pick(%{tid: tid} = state) do
    case :ets.lookup(tid, :size) do
      [{:size, n}] when n > 0 ->
        idx = :ets.update_counter(tid, :index, {2, 1, n - 1, 0})

        case :ets.lookup(tid, {:channel, idx}) do
          [{_, channel}] -> {:ok, channel}
          # the channel set shrank between reading :size and the lookup
          [] -> pick(state)
        end

      _ ->
        {:error, :no_channels}
    end
  end

  @impl true
  def update(%{tid: tid}, channels) do
    n = length(channels)
    indexed = channels |> Enum.with_index() |> Enum.map(fn {ch, i} -> {{:channel, i}, ch} end)

    :ets.insert(tid, [{:size, n} | indexed])
    :ets.select_delete(tid, [{{{:channel, :"$1"}, :_}, [{:>=, :"$1", n}], [true]}])
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
