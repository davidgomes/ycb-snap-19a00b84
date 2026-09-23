defmodule Warehouse.Components do
  import Ecto.Query

  alias Warehouse.Repo
  alias Warehouse.Schemas.{Component, Configuration}

  @spec number_available(Component.t()) :: integer
  def number_available(%Component{} = component) do
    component
    |> available_configurations()
    |> Enum.map(&configuration_available/1)
    |> Enum.sum()
  end

  @doc """
  Returns every SKU that can be picked to fulfill the given component, along
  with the quantity required per kit and the storage locations holding
  available parts for that SKU.
  """
  @spec picking_options(Component.t()) :: [map()]
  def picking_options(%Component{} = component) do
    component
    |> available_configurations()
    |> Enum.map(fn %{sku: sku, quantity: quantity} = configuration ->
      %{
        sku: sku,
        required_quantity_per_kit: quantity,
        available_quantity: configuration_available(configuration),
        available_locations: available_locations(sku.parts)
      }
    end)
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

  defp available_locations(parts) do
    parts
    |> Enum.group_by(& &1.location)
    |> Enum.map(fn {location, location_parts} ->
      %{location: location, available_quantity: length(location_parts)}
    end)
    |> Enum.sort_by(& &1.available_quantity, :desc)
  end

  defp excluded_picking_locations() do
    Application.get_env(:warehouse, :exluded_picking_locations, [])
  end

  defp configuration_available(%{sku: %{parts: parts}, quantity: quantity}) do
    parts
    |> length()
    |> div(quantity)
  end
end
