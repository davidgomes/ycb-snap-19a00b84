defmodule Hexpm.Repo.Migrations.AddReleasesSemverKeyIndexes do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up() do
    execute("""
    CREATE INDEX CONCURRENTLY IF NOT EXISTS releases_package_id_semver_key_index
    ON releases (package_id, semver_key DESC)
    """)

    execute("""
    CREATE INDEX CONCURRENTLY IF NOT EXISTS releases_package_id_stable_semver_key_index
    ON releases (package_id, stable DESC, semver_key DESC)
    """)
  end

  def down() do
    execute("DROP INDEX CONCURRENTLY IF EXISTS releases_package_id_stable_semver_key_index")
    execute("DROP INDEX CONCURRENTLY IF EXISTS releases_package_id_semver_key_index")
  end
end
