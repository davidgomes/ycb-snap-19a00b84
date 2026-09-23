defmodule Warehouse.Server do
  use GRPC.Server, service: Bottle.Inventory.V1.Service

  require Logger

  import Ecto.Query

  alias Warehouse.{Repo, Components, Schemas}

  alias Bottle.Inventory.V1.{
    Component,
    ListComponentAvailabilityRequest,
    ListComponentAvailabilityResponse,
    Location,
    Sku
  }

  alias Bottle.Inventory.V1.ListComponentAvailabilityResponse.PickingOption
  alias Bottle.Inventory.V1.ListComponentAvailabilityResponse.PickingOption.AvailableLocation
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
    total_available = picking_options |> Enum.map(& &1.available_quantity) |> Enum.sum()

    Logger.info("Component #{component_id} has #{total_available} available")

    ListComponentAvailabilityResponse.new(
      component: Component.new(id: component_id),
      total_available_quantity: total_available,
      picking_options: Enum.map(picking_options, &picking_option/1),
      request_id: Bottle.RequestId.write(:rpc)
    )
  end

  defp picking_option(%{sku: sku} = option) do
    PickingOption.new(
      sku: Sku.new(id: to_string(sku.id), name: sku.sku),
      required_quantity_per_kit: option.required_quantity_per_kit,
      available_locations: Enum.map(option.available_locations, &available_location/1)
    )
  end

  defp available_location(%{location: location, available_quantity: available_quantity}) do
    AvailableLocation.new(
      location: Location.new(id: to_string(location.id), name: location.name),
      available_quantity: available_quantity
    )
  end
end
