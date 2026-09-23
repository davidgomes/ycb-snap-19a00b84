defmodule Hexpm.Repo.Migrations.AddSemverKeysToReleases do
  use Ecto.Migration

  def up do
    alter table(:releases) do
      add :version_major, :integer
      add :version_minor, :integer
      add :version_patch, :integer
      add :version_stable, :boolean
    end

    execute """
    UPDATE releases SET
      version_major = substring(version from '^(\\d+)\\.')::integer,
      version_minor = substring(version from '^\\d+\\.(\\d+)\\.')::integer,
      version_patch = substring(version from '^\\d+\\.\\d+\\.(\\d+)')::integer,
      version_stable = split_part(version, '+', 1) NOT LIKE '%-%'
    """

    create index(:releases, [
             :package_id,
             :version_major,
             :version_minor,
             :version_patch,
             :version_stable
           ])
  end

  def down do
    alter table(:releases) do
      remove :version_major
      remove :version_minor
      remove :version_patch
      remove :version_stable
    end
  end
end
