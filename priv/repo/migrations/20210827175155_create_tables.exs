defmodule Warehouse.Repo.Migrations.CreateTables do
  use Ecto.Migration

  # The production tables are owned by another application. This migration only
  # mirrors the columns we read so the test database has the same shape.
  def change do
    create table(:components) do
      add :removed, :boolean, default: false
    end

    create table(:inventory_locations) do
      add :name, :string
      add :area, :string
      add :disabled, :boolean, default: false
      add :removed, :boolean, default: false

      timestamps()
    end

    create table(:inventory_skus) do
      add :removed, :boolean, default: false
      add :sku, :string

      timestamps()
    end

    create table(:inventory_parts) do
      add :uuid, :string
      add :serial_number, :string
      add :assembly_build_id, :integer
      add :rma_description, :string

      add :location_id, references(:inventory_locations), null: false
      add :sku_id, references(:inventory_skus), null: false

      timestamps()
    end

    create table(:inventory_configurations) do
      add :quantity, :integer, default: 1

      add :component_id, references(:components), null: false
      add :sku_id, references(:inventory_skus), null: false
    end

    create table(:inventory_part_movements) do
      add :location_id, references(:inventory_locations), null: false
      add :part_id, references(:inventory_parts), null: false

      timestamps(updated_at: false)
    end
  end
end
