defmodule GRPC.Client.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    table = GRPC.Client.LoadBalancing

    if :ets.whereis(table) == :undefined do
      :ets.new(table, [
        :named_table,
        :public,
        :set,
        {:read_concurrency, true},
        {:write_concurrency, true}
      ])
    end

    children = [
      {Registry, [keys: :unique, name: GRPC.Client.Registry]},
      {DynamicSupervisor, [name: GRPC.Client.Supervisor]}
    ]

    opts = [strategy: :one_for_one, name: GRPC.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
