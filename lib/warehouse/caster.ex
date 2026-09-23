defmodule Warehouse.Caster do
  @moduledoc """
  Encapsulate the logic to cast from Schemas to Bottles and back
  """

  alias Bottle.Inventory.V1.{Location, Part, Sku}
  alias Warehouse.Schemas

  def cast(%Part{} = part) do
    %{
      location_id: part.location.id,
      serial_number: part.serial_number,
      sku_id: part.sku.id,
      uuid: part.id
    }
  end

  def cast(%Schemas.Location{} = location) do
    Location.new(id: to_string(location.id), name: location.name)
  end

  def cast(%Schemas.Sku{} = sku) do
    Sku.new(id: to_string(sku.id), name: sku.sku)
  end
end
