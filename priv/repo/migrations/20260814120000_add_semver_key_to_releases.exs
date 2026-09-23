defmodule Hexpm.Repo.Migrations.AddSemverKeyToReleases do
  use Ecto.Migration

  # The backfill commits each batch, so a failed run keeps its progress and the
  # next run continues with the releases that still have no key.
  @disable_ddl_transaction true
  @disable_migration_lock true

  @batch_size 10_000

  # semver_sort_key/1 maps a version to bytes that sort like Version.compare/2:
  #
  #   * major, minor, and patch as numbers
  #   * 0xFF without a pre-release, so a version sorts after its pre-releases
  #   * otherwise every pre-release identifier, as 0x01 and a number or as 0x02,
  #     the text, and 0x00, then a closing 0x00 so fewer identifiers sort first
  #   * build metadata, which Version.compare/2 ignores, as a tiebreaker
  #
  # A number is its digit count, one byte or 0xFF and four bytes from 255 digits
  # on, followed by its digits.
  @semver_sort_key_number """
  CREATE OR REPLACE FUNCTION semver_sort_key_number(digits text) RETURNS bytea
  LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
  AS $$
    SELECT CASE
             WHEN length(n) < 255 THEN set_byte('\\x00'::bytea, 0, length(n))
             ELSE '\\xff'::bytea || int4send(length(n))
           END || convert_to(n, 'UTF8')
    FROM (SELECT coalesce(nullif(ltrim(digits, '0'), ''), '0') AS n) AS number
  $$
  """

  @semver_sort_key """
  CREATE OR REPLACE FUNCTION semver_sort_key(version text) RETURNS bytea
  LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE
  AS $$
  DECLARE
    build_start int := strpos(version, '+');
    main text := CASE WHEN build_start > 0 THEN left(version, build_start - 1) ELSE version END;
    pre_start int := strpos(main, '-');
    core text := CASE WHEN pre_start > 0 THEN left(main, pre_start - 1) ELSE main END;
    part text;
    key bytea := '\\x'::bytea;
  BEGIN
    IF core !~ '^[0-9]+\\.[0-9]+\\.[0-9]+$' THEN
      RAISE EXCEPTION 'invalid SemVer version: %', version
        USING ERRCODE = 'invalid_parameter_value';
    END IF;

    FOREACH part IN ARRAY string_to_array(core, '.') LOOP
      key := key || semver_sort_key_number(part);
    END LOOP;

    IF pre_start = 0 THEN
      key := key || '\\xff'::bytea;
    ELSE
      FOREACH part IN ARRAY string_to_array(substr(main, pre_start + 1), '.') LOOP
        IF part ~ '^[0-9]+$' THEN
          key := key || '\\x01'::bytea || semver_sort_key_number(part);
        ELSE
          key := key || '\\x02'::bytea || convert_to(part, 'UTF8') || '\\x00'::bytea;
        END IF;
      END LOOP;

      key := key || '\\x00'::bytea;
    END IF;

    IF build_start > 0 THEN
      key := key || convert_to(substr(version, build_start + 1), 'UTF8');
    END IF;

    RETURN key;
  END
  $$
  """

  @semver_stable """
  CREATE OR REPLACE FUNCTION semver_stable(version text) RETURNS boolean
  LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
  AS $$
    SELECT strpos(split_part(version, '+', 1), '-') = 0
  $$
  """

  @releases_set_semver_key """
  CREATE OR REPLACE FUNCTION releases_set_semver_key() RETURNS trigger
  LANGUAGE plpgsql
  AS $$
  BEGIN
    NEW.semver_key := semver_sort_key(NEW.version);
    NEW.stable := semver_stable(NEW.version);
    RETURN NEW;
  END
  $$
  """

  def up() do
    with_lock_timeout(fn ->
      query!(@semver_sort_key_number)
      query!(@semver_sort_key)
      query!(@semver_stable)
      query!(@releases_set_semver_key)

      query!("""
      ALTER TABLE releases
        ADD COLUMN IF NOT EXISTS semver_key bytea,
        ADD COLUMN IF NOT EXISTS stable boolean
      """)

      # Validated after the backfill, so SET NOT NULL can skip its table scan
      query!("ALTER TABLE releases DROP CONSTRAINT IF EXISTS releases_semver_key_not_null")

      query!("""
      ALTER TABLE releases
        ADD CONSTRAINT releases_semver_key_not_null
        CHECK (semver_key IS NOT NULL AND stable IS NOT NULL) NOT VALID
      """)

      query!("DROP TRIGGER IF EXISTS releases_set_semver_key ON releases")

      query!("""
      CREATE TRIGGER releases_set_semver_key
      BEFORE INSERT OR UPDATE OF version ON releases
      FOR EACH ROW EXECUTE FUNCTION releases_set_semver_key()
      """)
    end)

    backfill(0)

    with_lock_timeout(fn ->
      query!("ALTER TABLE releases VALIDATE CONSTRAINT releases_semver_key_not_null")

      query!("""
      ALTER TABLE releases
        ALTER COLUMN semver_key SET NOT NULL,
        ALTER COLUMN stable SET NOT NULL
      """)

      query!("ALTER TABLE releases DROP CONSTRAINT releases_semver_key_not_null")
    end)
  end

  def down() do
    with_lock_timeout(fn ->
      query!("DROP TRIGGER IF EXISTS releases_set_semver_key ON releases")
      query!("DROP FUNCTION IF EXISTS releases_set_semver_key()")

      query!("""
      ALTER TABLE releases
        DROP COLUMN IF EXISTS semver_key,
        DROP COLUMN IF EXISTS stable
      """)

      query!("DROP FUNCTION IF EXISTS semver_stable(text)")
      query!("DROP FUNCTION IF EXISTS semver_sort_key(text)")
      query!("DROP FUNCTION IF EXISTS semver_sort_key_number(text)")
    end)
  end

  # The trigger fills new rows, and it only fires when version is written, so
  # the backfill computes each key once.
  defp backfill(after_id) do
    %{rows: [[last_id]]} =
      query!(
        """
        WITH batch AS (
          SELECT id
          FROM releases
          WHERE id > $1 AND semver_key IS NULL
          ORDER BY id
          LIMIT $2
        ), updated AS (
          UPDATE releases
          SET semver_key = semver_sort_key(releases.version),
              stable = semver_stable(releases.version)
          FROM batch
          WHERE releases.id = batch.id
          RETURNING releases.id
        )
        SELECT max(id) FROM updated
        """,
        [after_id, @batch_size]
      )

    if last_id, do: backfill(last_id)
  end

  defp with_lock_timeout(fun) do
    {:ok, _} =
      repo().transaction(
        fn ->
          query!("SET LOCAL lock_timeout TO '5s'")
          fun.()
        end,
        timeout: :infinity
      )

    :ok
  end

  defp query!(sql, params \\ []) do
    repo().query!(sql, params, timeout: :infinity)
  end
end
