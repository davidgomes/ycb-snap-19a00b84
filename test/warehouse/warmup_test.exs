defmodule Warehouse.WarmupTest do
  use Warehouse.DataCase, async: false

  import Mox

  alias Warehouse.{AdditiveMap, Component, Warmup}

  setup do
    stub(Warehouse.MockEvents, :broadcast_sku_quantities, fn _, _ -> :ok end)
    stub(Warehouse.Clients.Assembly.Mock, :request_component_demands, fn -> [] end)

    :ok
  end

  test "run/0 starts a process for every SKU" do
    sku = insert(:sku)
    assert Warehouse.SkuRegistry |> Registry.lookup(to_string(sku.id)) |> length() == 0

    assert :ok = Warmup.run()

    assert Warehouse.SkuRegistry |> Registry.lookup(to_string(sku.id)) |> length() == 1
  end

  test "run/0 starts a process for every Component" do
    component = insert(:component)
    assert Warehouse.ComponentRegistry |> Registry.lookup(to_string(component.id)) |> length() == 0

    assert :ok = Warmup.run()

    assert Warehouse.ComponentRegistry |> Registry.lookup(to_string(component.id)) |> length() == 1
  end

  test "run/0 loads assembly demand once the component processes are running" do
    sku = insert(:sku)
    component = insert(:component)
    insert(:kit, component: component, sku: sku, quantity: 2)

    expect(Warehouse.Clients.Assembly.Mock, :request_component_demands, fn ->
      [%{component_id: component.id, demand_quantity: 10}]
    end)

    assert :ok = Warmup.run()

    assert Component.get_sku_demands() |> AdditiveMap.get(sku.id) == 20
  end
end
