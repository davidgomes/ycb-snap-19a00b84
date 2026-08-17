defmodule Warehouse.ComponentsTest do
  use Warehouse.DataCase

  import Warehouse.Factory

  alias Warehouse.Components
  alias Warehouse.Schemas.{Component, Configuration, Location, Part, Sku}

  describe "number_available/1" do
    test "calculates available configurations for a given component" do
      component = insert(:component)
      sku = insert(:sku)
      _config = insert(:configuration, component: component, sku: sku, quantity: 2)
      storage_loc = insert(:location, area: :storage)
      other_loc = insert(:location, area: :receiving)

      # 4 parts in storage -> 4 / 2 = 2 available
      insert_list(4, :part, sku: sku, location: storage_loc)
      # 1 part in receiving (should not count)
      insert(:part, sku: sku, location: other_loc)
      # 1 part assigned to assembly build (should not count)
      insert(:part, sku: sku, location: storage_loc, assembly_build_id: 123)
      # 1 part with rma description (should not count)
      insert(:part, sku: sku, location: storage_loc, rma_description: "broken")

      assert Components.number_available(component) == 2
    end
  end
end
