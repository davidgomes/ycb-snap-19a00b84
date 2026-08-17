defmodule GRPC.Client.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    GRPC.Client.Connection.init_ets_table()

    children = [
      {Registry, [keys: :unique, name: GRPC.Client.Registry]},
      {DynamicSupervisor, [name: GRPC.Client.Supervisor]}
    ]

    opts = [strategy: :one_for_one, name: GRPC.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
