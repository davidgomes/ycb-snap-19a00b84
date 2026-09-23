defmodule Warehouse.Server do
  use GRPC.Server, service: Bottle.Inventory.V1.Service

  require Logger

  import Ecto.Query

  alias Warehouse.{Repo, Components, Schemas}
  alias Bottle.Inventory.V1.{Component, ListComponentAvailabilityRequest, ListComponentAvailabilityResponse, Location, Sku}
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
    number_available = Components.number_available(component)

    Logger.info("Component #{component_id} has #{number_available} available")

    ListComponentAvailabilityResponse.new(
      component: Component.new(id: component_id),
      total_available_quantity: number_available,
      picking_options: picking_options(component),
      request_id: Bottle.RequestId.write(:rpc)
    )
  end

  # TODO: this duplicates a lot of Components.number_available/1 and should be cleaned up
  defp picking_options(%Schemas.Component{id: component_id}) do
    excluded_locations = Application.get_env(:warehouse, :exluded_picking_locations, [])

    query =
      from c in Schemas.Configuration,
        join: s in assoc(c, :sku),
        join: p in assoc(s, :parts),
        join: l in assoc(p, :location),
        where: c.component_id == ^component_id,
        where: is_nil(p.assembly_build_id),
        where: is_nil(p.rma_description),
        where: l.area == :storage,
        where: l.id not in ^excluded_locations,
        preload: [sku: {s, parts: {p, location: l}}]

    query
    |> Repo.all()
    |> Enum.map(fn %{sku: sku, quantity: quantity} ->
      {location, count} =
        sku.parts
        |> Enum.group_by(& &1.location)
        |> Enum.map(fn {location, parts} -> {location, length(parts)} end)
        |> Enum.max_by(fn {_, count} -> count end, fn -> {nil, 0} end)

      ListComponentAvailabilityResponse.PickingOption.new(
        sku: Sku.new(id: to_string(sku.id), name: sku.sku || ""),
        recommended_location: location && Location.new(id: to_string(location.id), name: ""),
        required_quantity_per_kit: quantity,
        available_quantity: count
      )
    end)
  end
end
