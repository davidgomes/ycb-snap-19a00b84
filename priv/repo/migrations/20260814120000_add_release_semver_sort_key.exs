defmodule Hexpm.Repo.Migrations.AddReleaseSemverSortKey do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  @batch_size 10_000

  def up() do
    locked_transaction([
      """
      ALTER TABLE releases
        ADD COLUMN IF NOT EXISTS semver_sort_key bytea,
        ADD COLUMN IF NOT EXISTS stable boolean
      """,
      # A number is encoded as its digit count in one byte followed by its
      # digits, so byte order matches numeric order. set_byte/3 silently
      # truncates the count, which is why longer numbers raise instead.
      ~S"""
      CREATE OR REPLACE FUNCTION release_semver_number_key(digits text) RETURNS bytea AS $$
      BEGIN
        IF length(digits) > 255 THEN
          RAISE EXCEPTION 'SemVer numbers can have at most 255 digits';
        END IF;

        RETURN set_byte('\x00'::bytea, 0, length(digits)) || convert_to(digits, 'UTF8');
      END;
      $$ LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE
      """,
      # Byte order of the key is SemVer precedence: build metadata is ignored,
      # a release (0x02) sorts after its prereleases (0x01), numeric prerelease
      # identifiers (0x01) sort before alphanumeric ones (0x02), and
      # alphanumeric identifiers end with 0x00 so a prefix sorts first.
      ~S"""
      CREATE OR REPLACE FUNCTION release_semver_sort_key(version text) RETURNS bytea AS $$
      DECLARE
        precedence text := split_part(version, '+', 1);
        dash integer := strpos(precedence, '-');
        identifier text;
        key bytea := ''::bytea;
      BEGIN
        FOREACH identifier IN ARRAY string_to_array(
          CASE WHEN dash = 0 THEN precedence ELSE left(precedence, dash - 1) END,
          '.'
        ) LOOP
          key := key || release_semver_number_key(identifier);
        END LOOP;

        IF dash = 0 THEN
          RETURN key || '\x02'::bytea;
        END IF;

        key := key || '\x01'::bytea;

        FOREACH identifier IN ARRAY string_to_array(substr(precedence, dash + 1), '.') LOOP
          IF identifier ~ '^[0-9]+$' THEN
            key := key || '\x01'::bytea || release_semver_number_key(identifier);
          ELSE
            key := key || '\x02'::bytea || convert_to(identifier, 'UTF8') || '\x00'::bytea;
          END IF;
        END LOOP;

        RETURN key;
      END;
      $$ LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE
      """,
      """
      CREATE OR REPLACE FUNCTION releases_set_semver_sort_key() RETURNS trigger AS $$
      BEGIN
        NEW.semver_sort_key := release_semver_sort_key(NEW.version);
        NEW.stable := strpos(split_part(NEW.version, '+', 1), '-') = 0;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql
      """,
      "DROP TRIGGER IF EXISTS releases_set_semver_sort_key ON releases",
      """
      CREATE TRIGGER releases_set_semver_sort_key
      BEFORE INSERT OR UPDATE OF version, semver_sort_key, stable ON releases
      FOR EACH ROW EXECUTE FUNCTION releases_set_semver_sort_key()
      """
    ])

    backfill()

    locked_transaction([
      "ALTER TABLE releases DROP CONSTRAINT IF EXISTS releases_semver_sort_key_not_null",
      """
      ALTER TABLE releases ADD CONSTRAINT releases_semver_sort_key_not_null
      CHECK (semver_sort_key IS NOT NULL AND stable IS NOT NULL) NOT VALID
      """
    ])

    # Validation scans the table but only takes a SHARE UPDATE EXCLUSIVE lock,
    # so reads and writes continue. SET NOT NULL then skips its own scan.
    locked_transaction([
      "ALTER TABLE releases VALIDATE CONSTRAINT releases_semver_sort_key_not_null"
    ])

    locked_transaction([
      """
      ALTER TABLE releases
        ALTER COLUMN semver_sort_key SET NOT NULL,
        ALTER COLUMN stable SET NOT NULL
      """,
      "ALTER TABLE releases DROP CONSTRAINT releases_semver_sort_key_not_null"
    ])
  end

  def down() do
    locked_transaction([
      "DROP TRIGGER IF EXISTS releases_set_semver_sort_key ON releases",
      "DROP FUNCTION IF EXISTS releases_set_semver_sort_key()",
      "DROP FUNCTION IF EXISTS release_semver_sort_key(text)",
      "DROP FUNCTION IF EXISTS release_semver_number_key(text)",
      """
      ALTER TABLE releases
        DROP COLUMN IF EXISTS semver_sort_key,
        DROP COLUMN IF EXISTS stable
      """
    ])
  end

  defp locked_transaction(statements) do
    {:ok, _} =
      repo().transaction(fn ->
        repo().query!("SET LOCAL lock_timeout TO '5s'")
        Enum.each(statements, &repo().query!(&1, [], timeout: :infinity))
      end)
  end

  # The trigger already covers new rows. Updating version to itself fires it
  # for the old ones, and each batch commits on its own so a rerun resumes.
  defp backfill() do
    %{rows: [[min_id, max_id]]} =
      repo().query!(
        "SELECT min(id), max(id) FROM releases WHERE semver_sort_key IS NULL",
        [],
        timeout: :infinity
      )

    if min_id do
      min_id
      |> Stream.iterate(&(&1 + @batch_size))
      |> Stream.take_while(&(&1 <= max_id))
      |> Enum.each(fn from_id ->
        repo().query!(
          """
          UPDATE releases SET version = version
          WHERE id >= $1 AND id < $2 AND semver_sort_key IS NULL
          """,
          [from_id, from_id + @batch_size],
          timeout: :infinity
        )
      end)
    end
  end
end
