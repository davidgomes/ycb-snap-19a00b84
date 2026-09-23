defmodule Warehouse.Components do
  import Ecto.Query

  alias Warehouse.Repo
  alias Warehouse.Schemas.{Component, Configuration}

  @type picking_option :: %{
          sku: %{id: String.t(), name: String.t()},
          required_quantity_per_kit: integer,
          available_locations: [%{location: %{id: String.t(), name: String.t()}, available_quantity: integer}]
        }

  @spec number_available(Component.t()) :: %{available: integer, options: [picking_option]}
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
        order_by: [asc: c.id],
        preload: [sku: {s, parts: {p, location: l}}]

    configurations = Repo.all(query)

    total =
      configurations
      |> Enum.map(&configuration_available/1)
      |> Enum.sum()

    %{available: total, options: Enum.map(configurations, &picking_option/1)}
  end

  defp excluded_picking_locations() do
    Application.get_env(:warehouse, :exluded_picking_locations, [])
  end

  defp configuration_available(%{sku: %{parts: parts}, quantity: quantity}) do
    parts
    |> length()
    |> div(quantity)
  end

  defp picking_option(%{sku: sku, quantity: quantity}) do
    locations =
      sku.parts
      |> Enum.group_by(& &1.location_id)
      |> Enum.map(fn {_location_id, [part | _] = parts} -> {part.location, length(parts)} end)
      |> Enum.sort_by(fn {location, count} -> {count, location.id} end)

    %{
      sku: %{id: to_string(sku.id), name: sku.sku},
      required_quantity_per_kit: quantity,
      available_locations:
        Enum.map(locations, fn {location, count} ->
          %{
            location: %{id: to_string(location.id), name: location.name},
            available_quantity: count
          }
        end)
    }
  end
end
