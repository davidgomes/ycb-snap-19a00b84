defmodule Warehouse.ServerTest do
  use Warehouse.DataCase, async: false

  alias Bottle.Inventory.V1.{ListComponentAvailabilityRequest, Stub}

  setup do
    {:ok, _pid, port} = GRPC.Server.start([Warehouse.Server], 0)
    on_exit(fn -> GRPC.Server.stop([Warehouse.Server]) end)

    {:ok, channel} = GRPC.Stub.connect("localhost:#{port}")
    %{channel: channel}
  end

  describe "list_component_availability/2" do
    test "streams picking information for each requested component", %{channel: channel} do
      location_one = insert(:location, area: :storage)
      location_one_id = to_string(location_one.id)
      location_two = insert(:location, area: :storage)
      location_two_id = to_string(location_two.id)

      component = insert(:component)
      component_id = to_string(component.id)

      %{sku: sku} = insert(:configuration, component: component, quantity: 2)
      sku_id = to_string(sku.id)

      insert_list(4, :part, sku: sku, location: location_one)
      insert_list(7, :part, sku: sku, location: location_two)

      removed_component = insert(:component, removed: true)

      {:ok, stream} =
        Stub.list_component_availability(
          channel,
          ListComponentAvailabilityRequest.new(components: [%{id: component_id}, %{id: to_string(removed_component.id)}])
        )

      assert [
               %{
                 component: %{id: ^component_id},
                 total_available_quantity: 5,
                 picking_options: [
                   %{
                     sku: %{id: ^sku_id},
                     required_quantity_per_kit: 2,
                     available_locations: [
                       %{location: %{id: ^location_one_id}, available_quantity: 4},
                       %{location: %{id: ^location_two_id}, available_quantity: 7}
                     ]
                   }
                 ]
               }
             ] = Enum.map(stream, fn {:ok, response} -> response end)
    end
  end
end
