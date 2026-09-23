defmodule Hexpm.Repo.Migrations.IndexReleasesBySemverSortKey do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up() do
    execute("""
    CREATE INDEX CONCURRENTLY IF NOT EXISTS releases_package_id_semver_sort_key_index
    ON releases (package_id, semver_sort_key DESC)
    """)
  end

  def down() do
    execute("DROP INDEX CONCURRENTLY IF EXISTS releases_package_id_semver_sort_key_index")
  end
end
