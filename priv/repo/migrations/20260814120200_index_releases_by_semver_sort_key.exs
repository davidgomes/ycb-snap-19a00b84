defmodule Hexpm.Repo.Migrations.IndexReleasesBySemverSortKey do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up() do
    create_if_not_exists(
      index(:releases, [:package_id, :semver_sort_key],
        name: :releases_package_id_semver_sort_key_idx,
        concurrently: true
      )
    )
  end

  def down() do
    drop_if_exists(
      index(:releases, [:package_id, :semver_sort_key],
        name: :releases_package_id_semver_sort_key_idx,
        concurrently: true
      )
    )
  end
end
