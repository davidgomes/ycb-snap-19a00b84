defmodule Hexpm.Repo.Migrations.IndexReleasesByStableSemverSortKey do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up() do
    execute("""
    CREATE INDEX CONCURRENTLY IF NOT EXISTS releases_package_id_stable_semver_sort_key_idx
    ON releases (package_id, stable DESC, semver_sort_key DESC)
    """)
  end

  def down() do
    execute("DROP INDEX CONCURRENTLY IF EXISTS releases_package_id_stable_semver_sort_key_idx")
  end
end
