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
    |> available_configurations()
    |> Enum.map(&configuration_available/1)
    |> Enum.sum()
  end

  @spec picking_options(Component.t()) :: [picking_option]
  def picking_options(%Component{} = component) do
    component
    |> available_configurations()
    |> Enum.map(&configuration_picking_option/1)
  end

  defp available_configurations(%Component{id: component_id}) do
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

    Repo.all(query)
  end

  defp excluded_picking_locations() do
    Application.get_env(:warehouse, :exluded_picking_locations, [])
  end

  defp configuration_available(%{sku: %{parts: parts}, quantity: quantity}) do
    parts
    |> length()
    |> div(quantity)
  end

  defp configuration_picking_option(%{sku: sku, quantity: quantity}) do
    %{
      sku: sku,
      required_quantity_per_kit: quantity,
      available_locations: available_locations(sku.parts)
    }
  end

  defp available_locations(parts) do
    parts
    |> Enum.group_by(& &1.location_id)
    |> Enum.map(fn {_location_id, [%{location: location} | _] = location_parts} ->
      %{location: location, available_quantity: length(location_parts)}
    end)
    |> Enum.sort_by(& &1.available_quantity, :desc)
  end
end
