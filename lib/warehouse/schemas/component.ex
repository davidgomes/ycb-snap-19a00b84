defmodule Warehouse.Schemas.Component do
  use Ecto.Schema

  @type t :: %__MODULE__{
          removed: boolean()
        }

  schema "components" do
    field :removed, :boolean, default: false
  end
end
