defmodule Warehouse.Server do
  use GRPC.Server, service: Bottle.Inventory.V1.Service

  require Logger

  import Ecto.Query

  alias Warehouse.{Repo, Components, Schemas}
  alias Bottle.Inventory.V1.{Component, ListComponentAvailabilityRequest, ListComponentAvailabilityResponse}
  alias Bottle.Inventory.V1.ListComponentAvailabilityResponse.PickingOption
  alias Bottle.Inventory.V1.ListComponentAvailabilityResponse.PickingOption.AvailableLocation
  alias Bottle.Inventory.V1.{Location, Sku}
  alias GRPC.Server

  @spec list_component_availability(ListComponentAvailabilityRequest.t(), GRPC.Server.Stream.t()) :: any()
  def list_component_availability(%{components: components}, stream) do
    component_ids = Enum.map(components, & &1.id)

    query =
      from c in Schemas.Component,
        where: c.removed == 0,
        where: c.id in ^component_ids

    Repo.transaction(
      fn ->
        query
        |> Repo.stream()
        |> Stream.map(&calculate_component_availability/1)
        |> Stream.each(&Server.send_reply(stream, &1))
        |> Stream.run()
      end,
      timeout: :infinity
    )
  end

  defp calculate_component_availability(%Schemas.Component{} = component) do
    component_id = to_string(component.id)
    picking_options = Components.picking_options(component)

    number_available =
      picking_options
      |> Enum.map(& &1.available_quantity)
      |> Enum.sum()

    Logger.info("Component #{component_id} has #{number_available} available")

    ListComponentAvailabilityResponse.new(
      component: Component.new(id: component_id),
      picking_options: Enum.map(picking_options, &build_picking_option/1),
      request_id: Bottle.RequestId.write(:rpc),
      total_available_quantity: number_available
    )
  end

  defp build_picking_option(picking_option) do
    PickingOption.new(
      available_locations: Enum.map(picking_option.available_locations, &build_available_location/1),
      required_quantity_per_kit: picking_option.required_quantity_per_kit,
      sku: Sku.new(id: to_string(picking_option.sku.id), name: picking_option.sku.sku)
    )
  end

  defp build_available_location(%{location: location, available_quantity: available_quantity}) do
    AvailableLocation.new(
      available_quantity: available_quantity,
      location: Location.new(id: to_string(location.id), name: location.name)
    )
  end
end
