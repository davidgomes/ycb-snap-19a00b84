defmodule Warehouse.Components do
  import Ecto.Query

  alias Warehouse.Repo
  alias Warehouse.Schemas.{Component, Configuration, Location, Sku}

  @type available_location :: %{location: Location.t(), available_quantity: integer}

  @type picking_option :: %{
          sku: Sku.t(),
          required_quantity_per_kit: integer,
          available_locations: [available_location]
        }

  @spec number_available(Component.t()) :: integer
  def number_available(%Component{} = component) do
    component
    |> picking_options()
    |> total_available()
  end

  @spec total_available([picking_option]) :: integer
  def total_available(picking_options) do
    picking_options
    |> Enum.map(&kits_available/1)
    |> Enum.sum()
  end

  @doc """
  Lists every SKU that can be picked to fulfill the component, with the storage
  locations holding pickable parts for it. Locations are ordered by the most
  parts available first.
  """
  @spec picking_options(Component.t()) :: [picking_option]
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

  defp picking_option(%{sku: %{parts: parts} = sku, quantity: quantity}) do
    available_locations =
      parts
      |> Enum.group_by(& &1.location_id)
      |> Enum.map(fn {_location_id, [%{location: location} | _] = location_parts} ->
        %{location: location, available_quantity: length(location_parts)}
      end)
      |> Enum.sort_by(& &1.available_quantity, :desc)

    %{sku: sku, required_quantity_per_kit: quantity, available_locations: available_locations}
  end

  defp kits_available(%{required_quantity_per_kit: quantity, available_locations: locations}) do
    locations
    |> Enum.map(& &1.available_quantity)
    |> Enum.sum()
    |> div(quantity)
  end
end
