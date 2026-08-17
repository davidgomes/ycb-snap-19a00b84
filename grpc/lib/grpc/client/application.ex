defmodule GRPC.Client.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    ensure_lb_table()

    children = [
      {Registry, [keys: :unique, name: GRPC.Client.Registry]},
      {DynamicSupervisor, [name: GRPC.Client.Supervisor]}
    ]

    opts = [strategy: :one_for_one, name: GRPC.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp ensure_lb_table do
    table = GRPC.Client.Connection.lb_table()

    if :ets.whereis(table) == :undefined do
      :ets.new(table, [:set, :public, :named_table, read_concurrency: true])
    end

    :ok
  end
end
