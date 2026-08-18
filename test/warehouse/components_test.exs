defmodule Warehouse.ComponentsTest do
  use Warehouse.DataCase

  alias Warehouse.Components

  describe "number_available/1" do
    test "calculates available configurations for a given component" do
      component = insert(:component)
      location = insert(:location, area: :storage)

      double_sku = insert(:sku)
      insert(:configuration, component: component, quantity: 2, sku: double_sku)
      insert_list(5, :part, location: location, sku: double_sku)

      single_sku = insert(:sku)
      insert(:configuration, component: component, quantity: 1, sku: single_sku)
      insert_list(3, :part, location: location, sku: single_sku)

      assert Components.number_available(component) == 5
    end

    test "ignores parts that can not be picked" do
      component = insert(:component)
      sku = insert(:sku)
      insert(:configuration, component: component, quantity: 1, sku: sku)

      storage = insert(:location, area: :storage)
      insert(:part, location: storage, sku: sku)
      insert(:part, location: storage, sku: sku, assembly_build_id: 42)
      insert(:part, location: storage, sku: sku, rma_description: "cracked case")
      insert(:part, location: insert(:location, area: :assembly), sku: sku)

      assert Components.number_available(component) == 1
    end

    test "is zero when the component has no configurations" do
      assert Components.number_available(insert(:component)) == 0
    end
  end

  describe "picking_options/1" do
    test "groups the available parts of a configuration by location" do
      component = insert(:component)
      sku = insert(:sku)
      insert(:configuration, component: component, quantity: 2, sku: sku)

      shelf = insert(:location, area: :storage)
      bin = insert(:location, area: :storage)
      insert_list(3, :part, location: shelf, sku: sku)
      insert(:part, location: bin, sku: sku)

      assert [picking_option] = Components.picking_options(component)
      assert picking_option.required_quantity_per_kit == 2
      assert picking_option.sku.id == sku.id

      available_locations =
        picking_option.available_locations
        |> Enum.map(&{&1.location.id, &1.available_quantity})
        |> Enum.sort()

      assert available_locations == Enum.sort([{shelf.id, 3}, {bin.id, 1}])
    end

    test "does not pick from excluded locations" do
      component = insert(:component)
      sku = insert(:sku)
      insert(:configuration, component: component, quantity: 1, sku: sku)

      location = insert(:location, area: :storage)
      insert_list(2, :part, location: location, sku: sku)

      exclude_locations([location.id])

      assert Components.picking_options(component) == []
    end
  end

  defp exclude_locations(location_ids) do
    previous = Application.get_env(:warehouse, :exluded_picking_locations)
    Application.put_env(:warehouse, :exluded_picking_locations, location_ids)

    on_exit(fn -> Application.put_env(:warehouse, :exluded_picking_locations, previous) end)
  end
end
