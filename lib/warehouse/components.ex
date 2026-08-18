defmodule Warehouse.Components do
  import Ecto.Query

  alias Warehouse.Repo
  alias Warehouse.Schemas.{Component, Configuration}

  @spec number_available(Component.t()) :: %{available: integer, options: List.t()}
  def number_available(%Component{id: component_id}) do
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

    configurations = Repo.all(query)

    available =
      configurations
      |> Enum.map(&configuration_available/1)
      |> Enum.sum()

    %{available: available, options: Enum.map(configurations, &picking_options/1)}
  end

  defp excluded_picking_locations() do
    Application.get_env(:warehouse, :exluded_picking_locations, [])
  end

  defp configuration_available(%{sku: %{parts: parts}, quantity: quantity}) do
    parts
    |> length()
    |> div(quantity)
  end

  defp picking_options(%{sku: sku, quantity: quantity}) do
    available_locations =
      sku.parts
      |> Enum.group_by(& &1.location_id)
      |> Enum.map(fn {location_id, [%{location: location} | _] = parts} ->
        %{
          location: %{id: to_string(location_id), name: location.name},
          available_quantity: length(parts)
        }
      end)
      |> Enum.sort_by(& &1.available_quantity)

    %{
      sku: %{id: to_string(sku.id), name: sku.sku},
      required_quantity_per_kit: quantity,
      available_locations: available_locations
    }
  end
end
