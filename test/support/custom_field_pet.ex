defmodule MyApp.CustomFieldPet do
  @moduledoc """
  Defines an Ecto schema with sortable custom fields for testing.
  """
  use Ecto.Schema
  import Ecto.Query

  alias MyApp.Owner

  @derive {
    Flop.Schema,
    filterable: [],
    sortable: [:id, :age, :human_age, :scaled_age, :owner_age_desc],
    adapter_opts: [
      custom_fields: [
        human_age: [
          filter: {__MODULE__, :noop_filter, []},
          field_dynamic: {__MODULE__, :scaled_age, [factor: 7]},
          ecto_type: :integer
        ],
        scaled_age: [
          filter: {__MODULE__, :noop_filter, []},
          field_dynamic: {__MODULE__, :scaled_age, []},
          ecto_type: :integer
        ],
        owner_age_desc: [
          filter: {__MODULE__, :noop_filter, []},
          field_dynamic: {__MODULE__, :owner_age_desc, []},
          ecto_type: :integer,
          bindings: [:owner]
        ]
      ]
    ]
  }

  schema "pets" do
    field :age, :integer
    field :name, :string

    belongs_to :owner, Owner
  end

  def noop_filter(query, _, _), do: query

  def scaled_age(opts) do
    factor = Keyword.fetch!(opts, :factor)
    dynamic([p], p.age * ^factor)
  end

  def owner_age_desc(_opts) do
    dynamic([owner: o], o.age * -1)
  end
end
