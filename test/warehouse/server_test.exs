defmodule Warehouse.ServerTest do
  use Warehouse.DataCase

  import Warehouse.Factory

  alias Bottle.Inventory.V1.{Component, ListComponentAvailabilityRequest, ListComponentAvailabilityResponse, Sku}
  alias Warehouse.Server

  defmodule ReplyAdapter do
    def send_reply(test_pid, data, _opts), do: send(test_pid, {:reply, data})
  end

  defp list_component_availability(components) do
    request =
      ListComponentAvailabilityRequest.new(components: Enum.map(components, &Component.new(id: to_string(&1.id))))

    Server.list_component_availability(request, %GRPC.Server.Stream{adapter: ReplyAdapter, payload: self()})
  end

  describe "list_component_availability/2" do
    test "streams the picking options for each requested component" do
      component = insert(:component)
      sku = insert(:sku, sku: "ssd-m2-1tb")
      insert(:configuration, component: component, sku: sku, quantity: 2)
      shelf = insert(:location, area: :storage, name: "Shelf A")
      insert_list(5, :part, sku: sku, location: shelf)

      list_component_availability([component])

      assert_received {:reply, data}
      response = ListComponentAvailabilityResponse.decode(data)

      assert response.component == Component.new(id: to_string(component.id))
      assert response.total_available_quantity == 2
      assert [option] = response.picking_options
      assert option.sku == Sku.new(id: to_string(sku.id), name: "ssd-m2-1tb")
      assert option.required_quantity_per_kit == 2
      assert [available_location] = option.available_locations
      assert available_location.location.id == to_string(shelf.id)
      assert available_location.location.name == "Shelf A"
      assert available_location.available_quantity == 5
    end

    test "skips removed components" do
      component = insert(:component, removed: 1)

      list_component_availability([component])

      refute_received {:reply, _}
    end
  end
end
