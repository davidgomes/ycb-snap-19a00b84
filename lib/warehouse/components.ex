defmodule Warehouse.Components do
  import Ecto.Query

  alias Warehouse.Repo
  alias Warehouse.Schemas.{Component, Configuration, Location, Sku}

  @type picking_location :: %{location: Location.t(), available_quantity: non_neg_integer()}

  @type picking_option :: %{
          sku: Sku.t(),
          required_quantity_per_kit: pos_integer(),
          available_quantity: non_neg_integer(),
          available_locations: [picking_location()]
        }

  @spec number_available(Component.t()) :: integer
  def number_available(%Component{} = component) do
    component
    |> picking_options()
    |> Enum.map(& &1.available_quantity)
    |> Enum.sum()
  end

  @doc """
  Every SKU that satisfies the given component, along with the storage locations
  its parts can be picked from. Locations are ordered so the one holding the most
  parts comes first.
  """
  @spec picking_options(Component.t()) :: [picking_option()]
  def picking_options(%Component{id: component_id}) do
    query =
      from c in Configuration,
        join: s in assoc(c, :sku),
        join: p in assoc(s, :parts),
        join: l in assoc(p, :location),
        where: c.component_id == ^component_id,
        where: is_nil(p.assembly_build_id),
        where: is_nil(p.rma_description),
        where: l.area == :storage,
        where: l.id not in ^excluded_picking_locations(),
        preload: [sku: {s, parts: {p, location: l}}]

    query
    |> Repo.all()
    |> Enum.map(&picking_option/1)
  end

  defp excluded_picking_locations() do
    Application.get_env(:warehouse, :exluded_picking_locations, [])
  end

  defp picking_option(%Configuration{quantity: quantity, sku: sku}) do
    available_locations = available_locations(sku.parts)

    available_parts =
      available_locations
      |> Enum.map(& &1.available_quantity)
      |> Enum.sum()

    %{
      sku: sku,
      required_quantity_per_kit: quantity,
      available_quantity: div(available_parts, quantity),
      available_locations: available_locations
    }
  end

  defp available_locations(parts) do
    parts
    |> Enum.group_by(& &1.location_id)
    |> Enum.map(fn {_location_id, [%{location: location} | _] = located_parts} ->
      %{location: location, available_quantity: length(located_parts)}
    end)
    |> Enum.sort_by(& &1.available_quantity, :desc)
  end
end
