defmodule MyApp.CustomOrderPet do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Query

  @derive {
    Flop.Schema,
    filterable: [:name],
    sortable: [:dog_age, :name],
    adapter_opts: [
      custom_fields: [
        dog_age: [
          field_dynamic: {__MODULE__, :dog_age, []},
          ecto_type: :integer
        ]
      ]
    ]
  }

  schema "pets" do
    field :age, :integer
    field :name, :string
  end

  def dog_age(opts) do
    factor = Keyword.fetch!(opts, :factor)
    dynamic([p], fragment("? * ?", p.age, ^factor))
  end
end
