defmodule Warehouse.Warmup do
  @moduledoc """
  Populates our in memory caches once, while the application boots.

  A `Warehouse.GenServers.Sku` and a `Warehouse.GenServers.Component` process is
  started for every record in the database, and only once they are all running do
  we ask the assembly service for the demand of every component. Because this all
  happens before `Warehouse.Broadway` starts consuming messages, demand is never
  reported for a component that has no process yet, and we never refetch every
  demand again, which used to overwrite live demand with stale numbers.

  New SKUs and components are only picked up when the application restarts.
  """

  alias Warehouse.Clients.Assembly
  alias Warehouse.Component
  alias Warehouse.GenServers
  alias Warehouse.Repo
  alias Warehouse.Schemas

  require Logger

  @component_supervisor Warehouse.ComponentSupervisor
  @sku_supervisor Warehouse.SkuSupervisor

  @doc false
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :temporary
    }
  end

  @doc """
  Warms up the caches as a supervision tree child. There is no process to
  supervise afterwards, so we return `:ignore`, which also makes the supervisor
  wait for the warmup to finish before starting the children that come after us.
  """
  @spec start_link(keyword()) :: :ignore
  def start_link(_opts) do
    run()
    :ignore
  end

  @doc """
  Starts the SKU and component processes, then loads the current component demand
  from the assembly service.

  ## Examples

      iex> run()
      :ok

  """
  @spec run() :: :ok
  def run() do
    start_skus()
    start_components()
    load_component_demands()

    Logger.info("Warehouse cache warmed up")
  end

  defp start_skus() do
    skus = Repo.all(Schemas.Sku)

    Enum.each(skus, fn sku ->
      DynamicSupervisor.start_child(@sku_supervisor, {GenServers.Sku, sku})
    end)

    Logger.info("Started #{length(skus)} SKU processes")
  end

  defp start_components() do
    components = Repo.all(Schemas.Component)

    Enum.each(components, fn component ->
      DynamicSupervisor.start_child(@component_supervisor, {GenServers.Component, [component: component]})
    end)

    Logger.info("Started #{length(components)} component processes")
  end

  defp load_component_demands() do
    Assembly.request_component_demands()
    |> Stream.each(fn %{component_id: id, demand_quantity: demand} ->
      Component.update_component_demand(id, demand)
    end)
    |> Stream.run()
  end
end
