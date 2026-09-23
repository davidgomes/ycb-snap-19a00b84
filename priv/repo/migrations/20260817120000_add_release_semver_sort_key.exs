defmodule Hexpm.Repo.Migrations.AddReleaseSemverSortKey do
  use Ecto.Migration

  # Each backfill batch commits on its own. A run that fails part way through
  # resumes after the batches it already committed.
  @disable_ddl_transaction true
  @disable_migration_lock true

  @batch_size 10_000

  # Encodes a version so that comparing keys bytewise matches SemVer precedence.
  # Build metadata does not affect precedence and is left out.
  #
  #   * major, minor and patch are each their digit count byte followed by
  #     their digits, the regex rejects leading zeros
  #   * then 0x02 for a stable version, which sorts it after its pre-releases,
  #     or 0x01 followed by the pre-release identifiers
  #   * a numeric identifier is 0x01 and the number encoded as above, an
  #     alphanumeric identifier is 0x02 and its characters terminated by 0x00,
  #     so numeric identifiers sort first and a shorter identifier sorts before
  #     one it prefixes
  #   * fewer identifiers sort first because their key prefixes the longer key
  #
  # The accepted grammar is Elixir's Version.parse/1, with numbers of up to 255
  # digits instead of 14.
  @semver_key ~S"""
  CREATE OR REPLACE FUNCTION semver_key(version text, OUT sort_key bytea, OUT stable boolean)
  LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE AS $$
  DECLARE
    parts text[];
    number text;
    identifier text;
  BEGIN
    parts := regexp_match(
      version,
      '^(0|[1-9][0-9]{0,254})[.](0|[1-9][0-9]{0,254})[.](0|[1-9][0-9]{0,254})' ||
      '(?:-((?:0|[1-9][0-9]{0,254}|[0-9]*[A-Za-z-][0-9A-Za-z-]*)' ||
      '(?:[.](?:0|[1-9][0-9]{0,254}|[0-9]*[A-Za-z-][0-9A-Za-z-]*))*))?' ||
      '(?:[+][0-9A-Za-z-]+(?:[.][0-9A-Za-z-]+)*)?$'
    );

    IF parts IS NULL THEN
      RAISE EXCEPTION 'invalid SemVer version: %', version;
    END IF;

    sort_key := '\x'::bytea;

    FOREACH number IN ARRAY parts[1:3] LOOP
      sort_key := sort_key || set_byte('\x00'::bytea, 0, length(number)) ||
        convert_to(number, 'UTF8');
    END LOOP;

    stable := parts[4] IS NULL;

    IF stable THEN
      sort_key := sort_key || '\x02'::bytea;
    ELSE
      sort_key := sort_key || '\x01'::bytea;

      FOREACH identifier IN ARRAY string_to_array(parts[4], '.') LOOP
        IF identifier ~ '^[0-9]+$' THEN
          sort_key := sort_key || '\x01'::bytea ||
            set_byte('\x00'::bytea, 0, length(identifier)) || convert_to(identifier, 'UTF8');
        ELSE
          sort_key := sort_key || '\x02'::bytea || convert_to(identifier, 'UTF8') ||
            '\x00'::bytea;
        END IF;
      END LOOP;
    END IF;
  END
  $$
  """

  @set_semver_key """
  CREATE OR REPLACE FUNCTION releases_semver_key() RETURNS trigger
  LANGUAGE plpgsql AS $$
  BEGIN
    SELECT k.sort_key, k.stable INTO NEW.semver_sort_key, NEW.stable
    FROM semver_key(NEW.version) AS k;

    RETURN NEW;
  END
  $$
  """

  # The update does not fire the trigger, so each key is computed once.
  @backfill_batch """
  WITH batch AS (
    SELECT id
    FROM releases
    WHERE id > $1 AND semver_sort_key IS NULL
    ORDER BY id
    LIMIT $2
  ), updated AS (
    UPDATE releases AS r
    SET (semver_sort_key, stable) = (
      SELECT k.sort_key, k.stable FROM semver_key(r.version) AS k
    )
    FROM batch
    WHERE r.id = batch.id
  )
  SELECT max(id) FROM batch
  """

  def up() do
    with_lock_timeout([
      """
      ALTER TABLE releases
        ADD COLUMN IF NOT EXISTS semver_sort_key bytea,
        ADD COLUMN IF NOT EXISTS stable boolean
      """,
      @semver_key,
      @set_semver_key,
      "DROP TRIGGER IF EXISTS releases_semver_key ON releases",
      """
      CREATE TRIGGER releases_semver_key
      BEFORE INSERT OR UPDATE OF version ON releases
      FOR EACH ROW EXECUTE FUNCTION releases_semver_key()
      """
    ])

    backfill(0)

    # SET NOT NULL skips its table scan when a validated constraint already
    # proves the columns are not null, and validating only takes a lock that
    # lets reads and writes through.
    with_lock_timeout([
      """
      ALTER TABLE releases
        DROP CONSTRAINT IF EXISTS releases_semver_sort_key_not_null,
        ADD CONSTRAINT releases_semver_sort_key_not_null
          CHECK (semver_sort_key IS NOT NULL AND stable IS NOT NULL) NOT VALID
      """
    ])

    repo().query!(
      "ALTER TABLE releases VALIDATE CONSTRAINT releases_semver_sort_key_not_null",
      [],
      timeout: :infinity
    )

    with_lock_timeout([
      """
      ALTER TABLE releases
        ALTER COLUMN semver_sort_key SET NOT NULL,
        ALTER COLUMN stable SET NOT NULL
      """,
      "ALTER TABLE releases DROP CONSTRAINT releases_semver_sort_key_not_null"
    ])
  end

  def down() do
    execute("DROP TRIGGER IF EXISTS releases_semver_key ON releases")
    execute("DROP FUNCTION IF EXISTS releases_semver_key()")
    execute("DROP FUNCTION IF EXISTS semver_key(text)")

    alter table(:releases) do
      remove_if_exists :semver_sort_key
      remove_if_exists :stable
    end
  end

  defp backfill(after_id) do
    case repo().query!(@backfill_batch, [after_id, @batch_size], timeout: :infinity) do
      %{rows: [[nil]]} -> :ok
      %{rows: [[last_id]]} -> backfill(last_id)
    end
  end

  # The DDL needs ACCESS EXCLUSIVE, which would otherwise queue behind a long
  # read and block every query on releases while it waits.
  defp with_lock_timeout(statements) do
    {:ok, _} =
      repo().transaction(fn ->
        repo().query!("SET LOCAL lock_timeout TO '5s'")
        Enum.each(statements, &repo().query!(&1))
      end)
  end
end
