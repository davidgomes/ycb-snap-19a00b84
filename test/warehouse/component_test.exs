defmodule Warehouse.ComponentTest do
  use Warehouse.DataCase

  import Mox

  alias Warehouse.{AdditiveMap, Component, Sku}

  def demand_fixture(sku, kit_quantity, component_demand, parts_available) do
    component = insert(:component)
    insert(:kit, component: component, sku: sku, quantity: kit_quantity)
    insert_list(parts_available, :part, sku: sku)

    supervise(component)

    Component.update_component_demand(component.id, component_demand)
  end

  test "list_components/0 lists all components" do
    component = :component |> insert() |> supervise()
    assert Component.list_components() == [component]
  end

  test "list_components/1 filters to list only given component ids" do
    components = 4 |> insert_list(:component) |> supervise()
    _false_components = 8 |> insert_list(:component) |> supervise()

    ids = Enum.map(components, & &1.id)
    assert Component.list_components(ids) == components
  end

  test "get_component/1 finds a component by ID" do
    component = :component |> insert() |> supervise()
    assert Component.get_component(component.id) == component
  end

  test "get_component/1 returns nil if component doesn't exist or is not supervised" do
    component = build(:component)
    assert Component.get_component(component.id) == nil
  end

  test "get_sku_demands/0 returns an AdditiveMap of all sku demands" do
    stub(Warehouse.MockEvents, :broadcast_sku_quantities, fn _, _ -> :ok end)

    sku = :sku |> insert() |> supervise()
    demand_fixture(sku, 2, 10, 10)
    demand_fixture(sku, 4, 20, 20)

    demand = Component.get_sku_demands()
    assert AdditiveMap.get(demand, sku.id) == 100
  end

  test "update_component_demand/2 updates the component demand" do
    component = :component |> insert() |> supervise()
    assert :ok = Component.update_component_demand(component.id, 5)
  end

  describe "update_component_kits/1" do
    setup do
      stub(Warehouse.MockEvents, :broadcast_component_quantities, fn _, _ -> :ok end)
      stub(Warehouse.MockEvents, :broadcast_sku_quantities, fn _, _ -> :ok end)

      sku = :sku |> insert() |> supervise()
      component = insert(:component)
      kit = insert(:kit, component: component, sku: sku, quantity: 2)
      supervise(component)

      Component.update_component_demand(component.id, 5)
      assert_eventually(fn -> assert %{demand: 10} = Sku.get_sku_quantity(sku.id) end)

      %{component: component, kit: kit, sku: sku}
    end

    test "updates the demand of the new kits from assembly", %{component: component, kit: kit, sku: sku} do
      new_sku = :sku |> insert() |> supervise()
      kit |> Changeset.change(%{sku_id: new_sku.id}) |> Repo.update!()

      stub(Warehouse.Clients.Assembly.Mock, :request_component_demands, fn ->
        [%{component_id: to_string(component.id), demand_quantity: 3}]
      end)

      Component.update_component_kits(component.id)

      assert_eventually(fn -> assert %{demand: 6} = Sku.get_sku_quantity(new_sku.id) end)
      assert_eventually(fn -> assert %{demand: 0} = Sku.get_sku_quantity(sku.id) end)
    end

    test "resets demand if assembly has no demand for the component", %{component: component, sku: sku} do
      stub(Warehouse.Clients.Assembly.Mock, :request_component_demands, fn -> [] end)

      Component.update_component_kits(component.id)

      assert_eventually(fn -> assert %{demand: 0} = Sku.get_sku_quantity(sku.id) end)
    end
  end
end
