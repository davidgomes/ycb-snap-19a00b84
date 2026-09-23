defmodule Warehouse.ComponentsTest do
  use Warehouse.DataCase

  import Warehouse.Factory

  alias Warehouse.Components

  describe "number_available/1" do
    test "calculates available configurations for a given component" do
    end
  end

  describe "picking_options/1" do
    test "lists the storage locations holding available parts for each configured sku" do
      component = insert(:component)
      sku = insert(:sku)
      insert(:configuration, component: component, sku: sku, quantity: 2)

      small_shelf = insert(:location, area: :storage, name: "Shelf A")
      big_shelf = insert(:location, area: :storage, name: "Shelf B")
      assembly = insert(:location, area: :assembly, name: "Assembly")

      insert(:part, sku: sku, location: small_shelf)
      insert_list(3, :part, sku: sku, location: big_shelf)
      insert(:part, sku: sku, location: assembly)
      insert(:part, sku: sku, location: small_shelf, rma_description: "DOA")
      insert(:part, sku: sku, location: small_shelf, assembly_build_id: 1)

      assert [option] = Components.picking_options(component)
      assert option.sku.id == sku.id
      assert option.required_quantity_per_kit == 2

      assert [
               %{location: %{name: "Shelf B"}, available_quantity: 3},
               %{location: %{name: "Shelf A"}, available_quantity: 1}
             ] = option.available_locations
    end

    test "returns nothing when no parts are available" do
      component = insert(:component)
      insert(:configuration, component: component)

      assert [] = Components.picking_options(component)
    end
  end
end
