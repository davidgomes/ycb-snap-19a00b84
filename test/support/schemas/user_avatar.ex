defmodule EctoShorts.Support.Schemas.UserAvatar do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_avatars" do
    field :name, :string
    field :description, :string

    belongs_to :user, EctoShorts.Support.Schemas.User

    has_one :file_info, {"file_info_user_avatars", EctoShorts.Support.Schemas.FileInfo}

    timestamps()
  end

  @available_fields [
    :name,
    :description
  ]

  def changeset(model_or_changeset, attrs \\ %{}) do
    model_or_changeset
    |> cast(attrs, @available_fields)
    |> no_assoc_constraint(:file_info, name: "file_info_user_avatars_assoc_id_fkey")
  end
end
