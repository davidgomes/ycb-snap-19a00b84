defmodule Hexpm.Repo.Migrations.AddReleaseSemverSortKey do
  use Ecto.Migration

  # The backfill commits one batch at a time so it neither holds locks on
  # releases for its whole duration nor loses completed batches on failure.
  @disable_ddl_transaction true
  @disable_migration_lock true

  @batch_size 10_000

  # Numbers are ordered by digit count first, which is only correct because
  # SemVer forbids leading zeros. Counts that don't fit in one byte are escaped
  # with 0xFF followed by a four-byte count so any length stays ordered.
  @number_function ~S"""
  CREATE OR REPLACE FUNCTION semver_sort_key_number(digits text) RETURNS bytea
  LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
  AS $$
    SELECT CASE
      WHEN length(digits) < 255 THEN set_byte('\x00'::bytea, 0, length(digits))
      ELSE '\xff'::bytea || int4send(length(digits))
    END || convert_to(digits, 'UTF8')
  $$
  """

  # Byte order of the key matches Version.compare/2: major, minor and patch,
  # then 0x02 for releases or 0x01 for pre-releases so that pre-releases sort
  # first. Pre-release identifiers are 0x01 plus a number or 0x02 plus
  # NUL-terminated ASCII, so numeric identifiers sort before alphanumeric ones,
  # and the list ends with 0x00 so that shorter lists sort first. Build
  # metadata doesn't affect precedence and is ignored.
  @key_function ~S"""
  CREATE OR REPLACE FUNCTION semver_sort_key(version text) RETURNS bytea
  LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE
  AS $$
  DECLARE
    precedence text;
    core text;
    identifier text;
    key bytea;
  BEGIN
    -- Capture groups would make PostgreSQL use its much slower backtracking
    -- regex engine, so the version is only matched here and split below.
    IF version !~ ('^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)' ||
                   '(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?' ||
                   '(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$') THEN
      RAISE EXCEPTION 'invalid SemVer version: %', version USING ERRCODE = 'check_violation';
    END IF;

    precedence := split_part(version, '+', 1);
    core := split_part(precedence, '-', 1);

    key := semver_sort_key_number(split_part(core, '.', 1)) ||
      semver_sort_key_number(split_part(core, '.', 2)) ||
      semver_sort_key_number(split_part(core, '.', 3));

    IF precedence = core THEN
      RETURN key || '\x02'::bytea;
    END IF;

    key := key || '\x01'::bytea;

    FOREACH identifier IN ARRAY string_to_array(substr(precedence, length(core) + 2), '.') LOOP
      IF identifier ~ '^[0-9]+$' THEN
        IF identifier ~ '^0[0-9]' THEN
          RAISE EXCEPTION 'invalid SemVer version: %', version USING ERRCODE = 'check_violation';
        END IF;

        key := key || '\x01'::bytea || semver_sort_key_number(identifier);
      ELSE
        key := key || '\x02'::bytea || convert_to(identifier, 'UTF8') || '\x00'::bytea;
      END IF;
    END LOOP;

    RETURN key || '\x00'::bytea;
  END
  $$
  """

  @stable_function ~S"""
  CREATE OR REPLACE FUNCTION semver_stable(version text) RETURNS boolean
  LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
  AS $$
    SELECT position('-' IN split_part(version, '+', 1)) = 0
  $$
  """

  @trigger_function ~S"""
  CREATE OR REPLACE FUNCTION releases_set_semver_sort_key() RETURNS trigger
  LANGUAGE plpgsql
  AS $$
  BEGIN
    NEW.semver_sort_key := semver_sort_key(NEW.version);
    NEW.semver_stable := semver_stable(NEW.version);
    RETURN NEW;
  END
  $$
  """

  def up() do
    locked_transaction(fn ->
      repo().query!("""
      ALTER TABLE releases
        ADD COLUMN IF NOT EXISTS semver_sort_key bytea,
        ADD COLUMN IF NOT EXISTS semver_stable boolean
      """)

      repo().query!(@number_function)
      repo().query!(@key_function)
      repo().query!(@stable_function)
      repo().query!(@trigger_function)

      repo().query!("""
      CREATE OR REPLACE TRIGGER releases_set_semver_sort_key
      BEFORE INSERT OR UPDATE OF version ON releases
      FOR EACH ROW EXECUTE FUNCTION releases_set_semver_sort_key()
      """)
    end)

    backfill()

    # A validated CHECK constraint lets SET NOT NULL skip its table scan, and
    # validating takes a lock that doesn't block reads or writes.
    locked_transaction(fn ->
      repo().query!("""
      ALTER TABLE releases
        DROP CONSTRAINT IF EXISTS releases_semver_sort_key_not_null,
        ADD CONSTRAINT releases_semver_sort_key_not_null
          CHECK (semver_sort_key IS NOT NULL AND semver_stable IS NOT NULL) NOT VALID
      """)
    end)

    repo().query!(
      "ALTER TABLE releases VALIDATE CONSTRAINT releases_semver_sort_key_not_null",
      [],
      timeout: :infinity
    )

    locked_transaction(fn ->
      repo().query!("""
      ALTER TABLE releases
        ALTER COLUMN semver_sort_key SET NOT NULL,
        ALTER COLUMN semver_stable SET NOT NULL,
        DROP CONSTRAINT releases_semver_sort_key_not_null
      """)
    end)
  end

  def down() do
    locked_transaction(fn ->
      repo().query!("DROP TRIGGER IF EXISTS releases_set_semver_sort_key ON releases")
      repo().query!("DROP FUNCTION IF EXISTS releases_set_semver_sort_key()")

      repo().query!("""
      ALTER TABLE releases
        DROP COLUMN IF EXISTS semver_sort_key,
        DROP COLUMN IF EXISTS semver_stable
      """)

      repo().query!("DROP FUNCTION IF EXISTS semver_stable(text)")
      repo().query!("DROP FUNCTION IF EXISTS semver_sort_key(text)")
      repo().query!("DROP FUNCTION IF EXISTS semver_sort_key_number(text)")
    end)
  end

  defp locked_transaction(fun) do
    {:ok, _} =
      repo().transaction(fn ->
        repo().query!("SET LOCAL lock_timeout TO '5s'")
        fun.()
      end)

    :ok
  end

  defp backfill() do
    %{rows: [[first_id]]} =
      repo().query!("SELECT min(id) FROM releases WHERE semver_sort_key IS NULL")

    if first_id, do: backfill_after(first_id - 1)
  end

  defp backfill_after(after_id) do
    %{rows: [[last_id]]} =
      repo().query!(
        """
        WITH batch AS (
          SELECT id FROM releases WHERE id > $1 ORDER BY id LIMIT $2
        ), filled AS (
          UPDATE releases
          SET semver_sort_key = semver_sort_key(releases.version),
              semver_stable = semver_stable(releases.version)
          FROM batch
          WHERE releases.id = batch.id AND releases.semver_sort_key IS NULL
        )
        SELECT max(id) FROM batch
        """,
        [after_id, @batch_size]
      )

    if last_id, do: backfill_after(last_id)
  end
end
