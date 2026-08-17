defmodule MyApp.Fruit do
  @moduledoc """
  Defines an Ecto schema for testing.
  """
  use Ecto.Schema
  import Ecto.Query

  alias MyApp.Owner

  @derive {Flop.Schema,
           filterable: [
             :id,
             :name,
             :family,
             :attributes,
             :extra,
             :references,
             :owner_attributes,
             :owner_extra
           ],
           sortable: [:id, :name, :name_custom],
           join_fields: [
             owner_attributes: [
               binding: :owner,
               field: :attributes,
               path: [:owner, :attributes],
               ecto_type: {:map, :string}
             ],
             owner_extra: [
               binding: :owner,
               field: :extra,
               path: [:owner, :extra],
               ecto_type: :map
             ]
           ],
           custom_fields: [
             name_custom: [
               filter: {__MODULE__, :name_custom_filter, []},
               orderer: {__MODULE__, :name_custom_orderer, []},
               ecto_type: :string
             ]
           ],
           default_limit: 60,
           default_order: %{
             order_by: [:name],
             order_directions: [:asc]
           },
           pagination_types: [:first, :last, :offset]}

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "fruits" do
    field :name, :string
    field :family, :string
    field :attributes, :map
    field :extra, {:map, :string}
    field :references, {:array, :binary_id}

    belongs_to :owner, Owner
  end

  def name_custom_filter(query, %Flop.Filter{value: value}, _opts) do
    where(query, [f], f.name == ^value)
  end

  def name_custom_orderer(query, direction, _opts) do
    send(self(), {:orderer, direction})
    order_by(query, [f], [{^direction, f.name}])
  end
end
