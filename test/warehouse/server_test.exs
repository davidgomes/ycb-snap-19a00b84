defmodule Warehouse.ServerTest do
  use Warehouse.GRPCTestCase

  alias Bottle.Inventory.V1.{Component, ListComponentAvailabilityRequest, Stub}

  describe "ListComponentAvailability" do
    test "streams the availability and picking options of a component", %{channel: channel} do
      component = insert(:component)
      sku = insert(:sku)
      insert(:configuration, component: component, quantity: 2, sku: sku)

      location = insert(:location, area: :storage)
      insert_list(5, :part, location: location, sku: sku)

      assert [{:ok, response}] = list_component_availability(channel, component)

      assert response.component.id == to_string(component.id)
      assert response.total_available_quantity == 2

      assert [picking_option] = response.picking_options
      assert picking_option.required_quantity_per_kit == 2
      assert picking_option.sku.id == to_string(sku.id)
      assert picking_option.sku.name == sku.sku

      assert [available_location] = picking_option.available_locations
      assert available_location.available_quantity == 5
      assert available_location.location.id == to_string(location.id)
      assert available_location.location.name == location.name
    end

    test "has no picking options when nothing can be picked", %{channel: channel} do
      component = insert(:component)
      insert(:configuration, component: component, quantity: 1, sku: insert(:sku))

      assert [{:ok, response}] = list_component_availability(channel, component)

      assert response.total_available_quantity == 0
      assert response.picking_options == []
    end

    test "skips removed components", %{channel: channel} do
      component = insert(:component, removed: true)

      assert list_component_availability(channel, component) == []
    end
  end

  defp list_component_availability(channel, component) do
    request = ListComponentAvailabilityRequest.new(components: [Component.new(id: to_string(component.id))])

    {:ok, stream} = Stub.list_component_availability(channel, request)

    Enum.to_list(stream)
  end
end
