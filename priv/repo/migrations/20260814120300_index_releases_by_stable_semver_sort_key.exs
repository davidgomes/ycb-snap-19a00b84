defmodule Hexpm.Repo.Migrations.IndexReleasesByStableSemverSortKey do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up() do
    create_if_not_exists(
      index(:releases, [:package_id, :stable, :semver_sort_key],
        name: :releases_package_id_stable_semver_sort_key_idx,
        concurrently: true
      )
    )
  end

  def down() do
    drop_if_exists(
      index(:releases, [:package_id, :stable, :semver_sort_key],
        name: :releases_package_id_stable_semver_sort_key_idx,
        concurrently: true
      )
    )
  end
end
