defmodule Warehouse.ComponentsTest do
  use Warehouse.DataCase

  import Warehouse.Factory

  alias Warehouse.Components

  describe "number_available/1" do
    test "calculates available configurations for a given component" do
      component = insert(:component)
      location = insert(:location, area: :storage)

      single_sku = insert(:sku)
      insert(:configuration, component: component, sku: single_sku, quantity: 1)
      insert_list(2, :part, sku: single_sku, location: location)

      paired_sku = insert(:sku)
      insert(:configuration, component: component, sku: paired_sku, quantity: 2)
      insert_list(5, :part, sku: paired_sku, location: location)

      assert Components.number_available(component) == 4
    end
  end

  describe "picking_options/1" do
    test "lists each sku with the storage locations it can be picked from" do
      component = insert(:component)
      sku = insert(:sku)
      insert(:configuration, component: component, sku: sku, quantity: 2)

      small_shelf = insert(:location, area: :storage)
      big_shelf = insert(:location, area: :storage)
      assembly = insert(:location, area: :assembly)

      insert(:part, sku: sku, location: small_shelf)
      insert_list(3, :part, sku: sku, location: big_shelf)
      insert(:part, sku: sku, location: assembly)

      assert [option] = Components.picking_options(component)
      assert option.sku.id == sku.id
      assert option.required_quantity == 2
      assert option.available_quantity == 2

      assert [
               %{location: %{id: big_shelf_id}, available_quantity: 3},
               %{location: %{id: small_shelf_id}, available_quantity: 1}
             ] = option.locations

      assert big_shelf_id == big_shelf.id
      assert small_shelf_id == small_shelf.id
    end

    test "orders skus by how many kits they can fulfill" do
      component = insert(:component)
      location = insert(:location, area: :storage)

      scarce_sku = insert(:sku)
      insert(:configuration, component: component, sku: scarce_sku)
      insert(:part, sku: scarce_sku, location: location)

      plentiful_sku = insert(:sku)
      insert(:configuration, component: component, sku: plentiful_sku)
      insert_list(3, :part, sku: plentiful_sku, location: location)

      assert [%{sku: first_sku}, %{sku: second_sku}] = Components.picking_options(component)
      assert first_sku.id == plentiful_sku.id
      assert second_sku.id == scarce_sku.id
    end

    test "ignores excluded picking locations" do
      component = insert(:component)
      sku = insert(:sku)
      insert(:configuration, component: component, sku: sku)

      [excluded_location_id | _] = Application.get_env(:warehouse, :exluded_picking_locations)
      excluded_location = insert(:location, id: excluded_location_id, area: :storage)
      insert(:part, sku: sku, location: excluded_location)

      assert Components.picking_options(component) == []
    end
  end
end
