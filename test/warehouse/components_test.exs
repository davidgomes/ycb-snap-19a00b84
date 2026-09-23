defmodule Warehouse.ComponentsTest do
  use Warehouse.DataCase

  alias Warehouse.Components

  describe "number_available/1" do
    test "only counts parts in storage locations" do
      storage_location = insert(:location, area: :storage)
      assembly_location = insert(:location, area: :assembly)

      component = insert(:component)
      %{sku: sku} = insert(:configuration, component: component, quantity: 2)

      insert_list(10, :part, sku: sku, location: storage_location)
      insert_list(200, :part, sku: sku, location: assembly_location)

      assert %{available: 5} = Components.number_available(component)
    end

    test "ignores parts assigned to a build or marked for RMA" do
      location = insert(:location, area: :storage)

      component = insert(:component)
      %{sku: sku} = insert(:configuration, component: component)

      insert_list(3, :part, sku: sku, location: location)
      insert_list(2, :part, sku: sku, location: location, assembly_build_id: 1)
      insert_list(2, :part, sku: sku, location: location, rma_description: "broken")

      assert %{available: 3} = Components.number_available(component)
    end

    test "sums every configuration of the component" do
      location = insert(:location, area: :storage)
      component = insert(:component)

      %{sku: sku_one} = insert(:configuration, component: component, quantity: 2)
      %{sku: sku_two} = insert(:configuration, component: component, quantity: 4)

      insert_list(10, :part, sku: sku_one, location: location)
      insert_list(8, :part, sku: sku_two, location: location)

      assert %{available: 7} = Components.number_available(component)
    end

    test "returns picking options for every sku and location" do
      location_one = insert(:location, area: :storage)
      location_one_id = to_string(location_one.id)
      location_two = insert(:location, area: :storage)
      location_two_id = to_string(location_two.id)
      location_three = insert(:location, area: :storage)
      location_three_id = to_string(location_three.id)

      component = insert(:component)

      %{sku: sku_one} = insert(:configuration, component: component, quantity: 2)
      sku_one_id = to_string(sku_one.id)
      %{sku: sku_two} = insert(:configuration, component: component, quantity: 4)
      sku_two_id = to_string(sku_two.id)

      insert_list(31, :part, sku: sku_one, location: location_two)
      insert_list(10, :part, sku: sku_one, location: location_one)
      insert_list(40, :part, sku: sku_two, location: location_three)

      assert %{
               available: 30,
               options: [
                 %{
                   sku: %{id: ^sku_one_id},
                   required_quantity_per_kit: 2,
                   available_locations: [
                     %{location: %{id: ^location_one_id}, available_quantity: 10},
                     %{location: %{id: ^location_two_id}, available_quantity: 31}
                   ]
                 },
                 %{
                   sku: %{id: ^sku_two_id},
                   required_quantity_per_kit: 4,
                   available_locations: [
                     %{location: %{id: ^location_three_id}, available_quantity: 40}
                   ]
                 }
               ]
             } = Components.number_available(component)
    end
  end
end
