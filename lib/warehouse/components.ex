defmodule Warehouse.Components do
  import Ecto.Query

  alias Warehouse.Repo
  alias Warehouse.Schemas.{Component, Configuration}

  @spec number_available(Component.t()) :: integer
  def number_available(%Component{} = component) do
    component
    |> pickable_configurations()
    |> total_available()
  end

  @doc """
  Returns every configuration of the component, preloaded with the sku and the
  parts (and their locations) that can currently be picked for it.
  """
  @spec pickable_configurations(Component.t()) :: [Configuration.t()]
  def pickable_configurations(%Component{id: component_id}) do
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

  @spec total_available([Configuration.t()]) :: integer
  def total_available(configurations) do
    configurations
    |> Enum.map(&configuration_available/1)
    |> Enum.sum()
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
