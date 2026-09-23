defmodule Warehouse.Components do
  import Ecto.Query

  alias Warehouse.Repo
  alias Warehouse.Schemas.{Component, Configuration, Location, Sku}

  @type picking_location :: %{
          location: Location.t(),
          available_quantity: non_neg_integer()
        }

  @type picking_option :: %{
          sku: Sku.t(),
          required_quantity: pos_integer(),
          available_quantity: non_neg_integer(),
          locations: [picking_location()]
        }

  @spec number_available(Component.t()) :: integer
  def number_available(%Component{} = component) do
    component
    |> picking_options()
    |> total_available()
  end

  @doc """
  Sums how many kits of a component can be picked across all of the given
  picking options.
  """
  @spec total_available([picking_option()]) :: integer
  def total_available(picking_options) do
    picking_options
    |> Enum.map(& &1.available_quantity)
    |> Enum.sum()
  end

  @doc """
  Lists every SKU that can be picked to fulfill a component, along with the
  storage locations holding pickable parts of that SKU. Options and locations
  are ordered with the most available first.
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
    |> Enum.sort_by(& &1.available_quantity, :desc)
  end

  defp excluded_picking_locations() do
    Application.get_env(:warehouse, :exluded_picking_locations, [])
  end

  defp picking_option(%{sku: %{parts: parts} = sku, quantity: quantity}) do
    %{
      sku: sku,
      required_quantity: quantity,
      available_quantity: div(length(parts), quantity),
      locations: picking_locations(parts)
    }
  end

  defp picking_locations(parts) do
    parts
    |> Enum.group_by(& &1.location_id, & &1.location)
    |> Enum.map(fn {_location_id, [location | _] = locations} ->
      %{location: location, available_quantity: length(locations)}
    end)
    |> Enum.sort_by(& &1.available_quantity, :desc)
  end
end
