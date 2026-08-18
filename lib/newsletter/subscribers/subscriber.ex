defmodule Newsletter.Subscribers.Subscriber do
  use Ecto.Schema
  import Ecto.Changeset

  schema "subscribers" do
    field :name, :string
    field :email, :string

    timestamps()
  end

  @doc false
  def changeset(subscriber, attrs) do
    subscriber
    |> cast(attrs, [:name, :email])
    |> validate_required([:name, :email])
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+$/, message: "must be a valid email address")
    |> unique_constraint(:email)
  end
end
