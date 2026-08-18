defmodule Newsletter.Repo.Migrations.CreateSubscribers do
  use Ecto.Migration

  def change do
    create table(:subscribers) do
      add :name, :string, null: false
      add :email, :string, null: false

      timestamps()
    end

    create unique_index(:subscribers, [:email])
  end
end
