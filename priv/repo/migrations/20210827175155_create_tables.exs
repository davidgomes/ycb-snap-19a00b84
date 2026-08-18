defmodule Warehouse.Repo.Migrations.CreateTables do
  use Ecto.Migration

  def change do
    create table(:components) do
      add :removed, :boolean, default: false, null: false
    end

    create table(:inventory_locations) do
      add :area, :string, null: false
      add :disabled, :boolean, default: false, null: false
      add :name, :string
      add :removed, :boolean, default: false, null: false

      timestamps()
    end

    create table(:inventory_skus) do
      add :removed, :boolean, default: false, null: false
      add :sku, :string, null: false

      timestamps()
    end

    create unique_index(:inventory_skus, [:sku])

    create table(:inventory_configurations) do
      add :quantity, :integer, default: 1, null: false

      add :component_id, references(:components), null: false
      add :sku_id, references(:inventory_skus), null: false
    end

    create table(:inventory_parts) do
      add :assembly_build_id, :integer
      add :rma_description, :string
      add :serial_number, :string
      add :uuid, :string

      add :location_id, references(:inventory_locations)
      add :sku_id, references(:inventory_skus)

      timestamps()
    end

    create table(:inventory_part_movements) do
      add :location_id, references(:inventory_locations), null: false
      add :part_id, references(:inventory_parts), null: false

      timestamps(updated_at: false)
    end
  end
end
