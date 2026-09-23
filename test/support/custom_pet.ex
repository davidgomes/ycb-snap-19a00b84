defmodule MyApp.CustomPet do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Query

  @derive {
    Flop.Schema,
    filterable: [:name, :human_age],
    sortable: [:name, :human_age],
    adapter_opts: [
      custom_fields: [
        human_age: [
          filter: {__MODULE__, :human_age_filter, []},
          field_dynamic: {__MODULE__, :human_age, []},
          ecto_type: :integer
        ]
      ]
    ]
  }

  schema "pets" do
    field :age, :integer
    field :name, :string
  end

  def human_age(opts) do
    factor = Keyword.get(opts, :factor, 7)
    dynamic([p], fragment("(? * ?)", p.age, ^factor))
  end

  def human_age_filter(query, %Flop.Filter{value: value, op: :==}, _opts) do
    where(query, [p], p.age * 7 == ^value)
  end
end
