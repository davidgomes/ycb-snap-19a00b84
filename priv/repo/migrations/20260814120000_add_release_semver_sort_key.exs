defmodule Hexpm.Repo.Migrations.AddReleaseSemverSortKey do
  use Ecto.Migration

  # The backfill commits in batches, so a finalization that times out on its lock
  # can be retried by running the migration again: every step is idempotent and
  # the backfill skips rows that already have a key.
  @disable_ddl_transaction true
  @disable_migration_lock true

  @batch_size 10_000

  def up() do
    transaction([
      "ALTER TABLE releases ADD COLUMN IF NOT EXISTS semver_sort_key bytea",
      "ALTER TABLE releases ADD COLUMN IF NOT EXISTS stable boolean",
      # Encodes a digit string without leading zeros so that byte order matches
      # numeric order: longer numbers sort after shorter ones, equal lengths
      # compare digit by digit.
      """
      CREATE OR REPLACE FUNCTION semver_sort_key_number(digits text) RETURNS bytea
      LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE AS $$
        SELECT CASE
            WHEN length(digits) < 255 THEN set_byte('\\x00'::bytea, 0, length(digits))
            ELSE '\\xff'::bytea || int4send(length(digits))
          END || convert_to(digits, 'UTF8')
      $$
      """,
      # Returns a key whose byte order is SemVer precedence, and whether the
      # version is stable. Parses versions the way Elixir's Version does and
      # ignores build metadata. The key is the major, minor, and patch numbers,
      # followed by 0x03 for a stable version or by one entry per prerelease
      # identifier: 0x01 and the number for a numeric identifier, 0x02 and the
      # NUL-terminated text for an alphanumeric one. A version without a
      # prerelease therefore sorts after all of its prereleases, and a longer
      # prerelease after its prefix.
      """
      CREATE OR REPLACE FUNCTION semver_sort_key(version text, OUT sort_key bytea, OUT stable boolean)
      LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE AS $$
      DECLARE
        precedence text := split_part(version, '+', 1);
        dash integer := strpos(precedence, '-');
        pre text;
        part text;
      BEGIN
        IF dash > 0 THEN
          pre := substr(precedence, dash + 1);
          precedence := left(precedence, dash - 1);
        END IF;

        IF precedence !~ '^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$'
           OR (pre IS NOT NULL AND pre !~ '^[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*$') THEN
          RAISE EXCEPTION 'invalid SemVer version: %', version;
        END IF;

        sort_key := semver_sort_key_number(split_part(precedence, '.', 1))
          || semver_sort_key_number(split_part(precedence, '.', 2))
          || semver_sort_key_number(split_part(precedence, '.', 3));
        stable := pre IS NULL;

        IF stable THEN
          sort_key := sort_key || '\\x03'::bytea;
          RETURN;
        END IF;

        FOREACH part IN ARRAY string_to_array(pre, '.') LOOP
          IF part ~ '^[0-9]+$' THEN
            IF part ~ '^0.' THEN
              RAISE EXCEPTION 'invalid SemVer version: %', version;
            END IF;

            sort_key := sort_key || '\\x01'::bytea || semver_sort_key_number(part);
          ELSE
            sort_key := sort_key || '\\x02'::bytea || convert_to(part, 'UTF8') || '\\x00'::bytea;
          END IF;
        END LOOP;
      END;
      $$
      """,
      """
      CREATE OR REPLACE FUNCTION releases_set_semver_sort_key() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        SELECT key.sort_key, key.stable
        INTO NEW.semver_sort_key, NEW.stable
        FROM semver_sort_key(NEW.version) AS key;

        RETURN NEW;
      END;
      $$
      """,
      "DROP TRIGGER IF EXISTS releases_set_semver_sort_key ON releases",
      """
      CREATE TRIGGER releases_set_semver_sort_key
      BEFORE INSERT OR UPDATE OF version ON releases
      FOR EACH ROW EXECUTE FUNCTION releases_set_semver_sort_key()
      """
    ])

    backfill(0)

    transaction([
      """
      ALTER TABLE releases
        ALTER COLUMN semver_sort_key SET NOT NULL,
        ALTER COLUMN stable SET NOT NULL
      """
    ])
  end

  def down() do
    transaction([
      "DROP TRIGGER IF EXISTS releases_set_semver_sort_key ON releases",
      "ALTER TABLE releases DROP COLUMN IF EXISTS semver_sort_key, DROP COLUMN IF EXISTS stable",
      "DROP FUNCTION IF EXISTS releases_set_semver_sort_key()",
      "DROP FUNCTION IF EXISTS semver_sort_key(text)",
      "DROP FUNCTION IF EXISTS semver_sort_key_number(text)"
    ])
  end

  defp transaction(statements) do
    {:ok, _} =
      repo().transaction(fn ->
        repo().query!("SET LOCAL lock_timeout TO '5s'")
        Enum.each(statements, &repo().query!/1)
      end)
  end

  # Rows inserted or given a new version while this runs already have a key
  # from the trigger, and setting the key directly doesn't fire it again.
  defp backfill(after_id) do
    %{rows: [[last_id]]} =
      repo().query!(
        """
        WITH batch AS (
          SELECT id FROM releases WHERE id > $1 ORDER BY id LIMIT $2
        ), backfilled AS (
          UPDATE releases AS r
          SET (semver_sort_key, stable) =
            (SELECT key.sort_key, key.stable FROM semver_sort_key(r.version) AS key)
          FROM batch
          WHERE r.id = batch.id AND r.semver_sort_key IS NULL
        )
        SELECT max(id) FROM batch
        """,
        [after_id, @batch_size]
      )

    if last_id, do: backfill(last_id)
  end
end
