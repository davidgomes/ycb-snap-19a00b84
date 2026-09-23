defmodule Hexpm.Repo.Migrations.AddReleasesSemverKeys do
  use Ecto.Migration

  @core "split_part(split_part(version, '+', 1), '-', 1)"
  @no_build "split_part(version, '+', 1)"

  def up() do
    execute("""
    ALTER TABLE releases
      ADD COLUMN version_major bigint GENERATED ALWAYS AS ((split_part(#{@core}, '.', 1))::bigint) STORED,
      ADD COLUMN version_minor bigint GENERATED ALWAYS AS ((split_part(#{@core}, '.', 2))::bigint) STORED,
      ADD COLUMN version_patch bigint GENERATED ALWAYS AS ((split_part(#{@core}, '.', 3))::bigint) STORED,
      ADD COLUMN version_pre text GENERATED ALWAYS AS (
        CASE WHEN strpos(#{@no_build}, '-') > 0
          THEN substr(#{@no_build}, strpos(#{@no_build}, '-') + 1)
        END
      ) STORED
    """)

    create index(:releases, [
             :package_id,
             "version_major DESC",
             "version_minor DESC",
             "version_patch DESC",
             "version_pre DESC"
           ])
  end

  def down() do
    alter table(:releases) do
      remove :version_major
      remove :version_minor
      remove :version_patch
      remove :version_pre
    end
  end
end
