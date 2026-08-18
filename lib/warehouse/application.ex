defmodule Warehouse.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  def start(_type, _args) do
    # Order matters here. The warmup needs the assembly connection to ask for
    # component demand, and Broadway must not handle a message before every SKU
    # and component process is running and holds its demand.
    children =
      [
        {SpandexDatadog.ApiServer, [http: HTTPoison, host: "127.0.0.1", batch_size: 20]},
        {Task.Supervisor, name: Warehouse.TaskSupervisor},
        {Registry, keys: :unique, name: Warehouse.ComponentRegistry},
        {DynamicSupervisor, name: Warehouse.ComponentSupervisor, strategy: :one_for_one},
        {Registry, keys: :unique, name: Warehouse.SkuRegistry},
        {DynamicSupervisor, name: Warehouse.SkuSupervisor, strategy: :one_for_one},
        Warehouse.Repo,
        {GRPC.Server.Supervisor, {Warehouse.Endpoint, 50_051}}
      ] ++
        assembly_connection_children() ++
        warmup_children() ++
        [{Warehouse.Broadway, []}]

    Logger.info("Starting Warehouse")

    opts = [strategy: :one_for_one, name: Warehouse.Supervisor]

    {:ok, _pid} = Supervisor.start_link(children, opts)
  end

  defp assembly_connection_children() do
    if Application.get_env(:warehouse, Warehouse.Clients.Assembly.Connection)[:enabled?],
      do: [Warehouse.Clients.Assembly.Connection],
      else: []
  end

  defp warmup_children() do
    if Application.get_env(:warehouse, :warmup?, true),
      do: [Warehouse.Warmup],
      else: []
  end
end
