defmodule MyApp.PetCustomSort do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Query

  @derive {
    Flop.Schema,
    filterable: [:name],
    sortable: [:human_age, :id],
    adapter_opts: [
      custom_fields: [
        human_age: [
          field_dynamic: {__MODULE__, :human_age, [factor: 7]},
          ecto_type: :integer
        ]
      ]
    ]
  }

  @primary_key {:id, :id, autogenerate: true}
  schema "pets" do
    field :age, :integer
    field :name, :string
    field :human_age, :integer, virtual: true
  end

  def human_age(opts) do
    send(self(), {:field_dynamic, opts})
    factor = Keyword.fetch!(opts, :factor)
    dynamic([p], fragment("? * ?", p.age, ^factor))
  end
end
