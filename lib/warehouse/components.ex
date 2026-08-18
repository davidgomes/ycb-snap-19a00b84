defmodule Warehouse.Components do
  import Ecto.Query

  alias Warehouse.Repo
  alias Warehouse.Schemas.{Component, Configuration, Location, Sku}

  @type available_location :: %{location: Location.t(), available_quantity: integer()}

  @type picking_option :: %{
          sku: Sku.t(),
          required_quantity_per_kit: integer(),
          available_locations: [available_location()]
        }

  @doc """
  Lists every way a component can be picked. A component is made up of one or
  more configurations, and each configuration turns into an option holding the
  locations its sku can be picked from.
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

  @doc """
  The number of components that can be built out of the given picking options.
  """
  @spec available_quantity([picking_option()]) :: integer
  def available_quantity(picking_options) do
    picking_options
    |> Enum.map(&option_available_quantity/1)
    |> Enum.sum()
  end

  @spec number_available(Component.t()) :: integer
  def number_available(%Component{} = component) do
    component
    |> picking_options()
    |> available_quantity()
  end

  defp picking_option(%Configuration{quantity: quantity, sku: sku}) do
    %{
      available_locations: available_locations(sku.parts),
      required_quantity_per_kit: quantity,
      sku: sku
    }
  end

  defp available_locations(parts) do
    parts
    |> Enum.group_by(& &1.location_id)
    |> Enum.map(fn {_location_id, [%{location: location} | _] = location_parts} ->
      %{available_quantity: length(location_parts), location: location}
    end)
  end

  defp option_available_quantity(%{available_locations: locations, required_quantity_per_kit: quantity}) do
    locations
    |> Enum.map(& &1.available_quantity)
    |> Enum.sum()
    |> div(quantity)
  end

  defp excluded_picking_locations() do
    Application.get_env(:warehouse, :exluded_picking_locations, [])
  end
end
