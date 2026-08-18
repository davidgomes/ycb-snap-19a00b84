defmodule GRPC.Client.Connection.Table do
  @moduledoc false
  use GenServer

  @table __MODULE__

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def put(ref, lb_mod, lb_state, real_channels) do
    true = :ets.insert(@table, {ref, lb_mod, lb_state, real_channels})
    :ok
  end

  def get(ref) do
    case :ets.lookup(@table, ref) do
      [{^ref, lb_mod, lb_state, real_channels}] ->
        {:ok, lb_mod, lb_state, real_channels}

      [] ->
        :error
    end
  end

  def delete(ref) do
    :ets.delete(@table, ref)
    :ok
  end

  @impl true
  def init(:ok) do
    @table = :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    {:ok, nil}
  end
end
