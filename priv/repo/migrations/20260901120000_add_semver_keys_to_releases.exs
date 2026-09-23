defmodule Hexpm.Repo.Migrations.AddSemverKeysToReleases do
  use Ecto.Migration

  def up do
    alter table(:releases) do
      add :version_major, :bigint
      add :version_minor, :bigint
      add :version_patch, :bigint
      add :version_pre, :boolean
    end

    execute """
    CREATE FUNCTION releases_set_semver_keys() RETURNS trigger AS $$
    DECLARE
      core text := split_part(split_part(NEW.version, '+', 1), '-', 1);
    BEGIN
      NEW.version_major := split_part(core, '.', 1)::bigint;
      NEW.version_minor := split_part(core, '.', 2)::bigint;
      NEW.version_patch := split_part(core, '.', 3)::bigint;
      NEW.version_pre := position('-' in split_part(NEW.version, '+', 1)) > 0;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql
    """

    execute """
    CREATE TRIGGER releases_set_semver_keys
    BEFORE INSERT OR UPDATE OF version ON releases
    FOR EACH ROW EXECUTE FUNCTION releases_set_semver_keys()
    """

    execute "UPDATE releases SET version = version"

    create index(:releases, [
             :package_id,
             :version_pre,
             "version_major DESC",
             "version_minor DESC",
             "version_patch DESC"
           ])
  end

  def down do
    execute "DROP TRIGGER releases_set_semver_keys ON releases"
    execute "DROP FUNCTION releases_set_semver_keys()"

    alter table(:releases) do
      remove :version_major
      remove :version_minor
      remove :version_patch
      remove :version_pre
    end
  end
end
