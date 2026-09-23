defmodule Warehouse.ComponentsTest do
  use Warehouse.DataCase

  import Warehouse.Factory

  alias Warehouse.Components

  describe "number_available/1" do
    test "calculates available configurations for a given component" do
      component = insert(:component)
      storage = insert(:location, area: :storage)

      single_sku = insert(:sku)
      insert(:configuration, component: component, sku: single_sku, quantity: 1)
      insert_list(3, :part, sku: single_sku, location: storage)

      pair_sku = insert(:sku)
      insert(:configuration, component: component, sku: pair_sku, quantity: 2)
      insert_list(5, :part, sku: pair_sku, location: storage)

      assert Components.number_available(component) == 5
    end
  end

  describe "picking_options/1" do
    test "lists the storage locations to pick each sku from, fullest first" do
      component = insert(:component)
      sku = insert(:sku)
      insert(:configuration, component: component, sku: sku, quantity: 2)

      shelf_a = insert(:location, area: :storage)
      shelf_b = insert(:location, area: :storage)
      insert(:part, sku: sku, location: shelf_a)
      insert_list(3, :part, sku: sku, location: shelf_b)

      assert [option] = Components.picking_options(component)
      assert option.sku.id == sku.id
      assert option.required_quantity_per_kit == 2

      assert [{shelf_b.id, 3}, {shelf_a.id, 1}] ==
               Enum.map(option.available_locations, &{&1.location.id, &1.available_quantity})
    end

    test "ignores parts that can not be picked" do
      component = insert(:component)
      sku = insert(:sku)
      insert(:configuration, component: component, sku: sku)

      storage = insert(:location, area: :storage)
      excluded = insert(:location, area: :storage)
      exclude_picking_locations([excluded.id])

      insert(:part, sku: sku, location: insert(:location, area: :assembly))
      insert(:part, sku: sku, location: excluded)
      insert(:part, sku: sku, location: storage, assembly_build_id: 1)
      insert(:part, sku: sku, location: storage, rma_description: "dead on arrival")

      assert Components.picking_options(component) == []
      assert Components.number_available(component) == 0
    end
  end

  defp exclude_picking_locations(location_ids) do
    previous = Application.fetch_env!(:warehouse, :exluded_picking_locations)
    Application.put_env(:warehouse, :exluded_picking_locations, location_ids)
    on_exit(fn -> Application.put_env(:warehouse, :exluded_picking_locations, previous) end)
  end
end
