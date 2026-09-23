defmodule Hexpm.Repo.Migrations.AddReleaseSemverSortKey do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  @batch_size 10_000

  # Every step is idempotent so that a run that stops partway, for example when
  # finalization times out waiting for its lock, resumes after the committed
  # backfill batches.
  def up() do
    transaction_with_lock_timeout(fn ->
      repo().query!("""
      ALTER TABLE releases
        ADD COLUMN IF NOT EXISTS semver_sort_key bytea,
        ADD COLUMN IF NOT EXISTS stable boolean
      """)

      # Numbers sort by digit count and then by digits. SemVer forbids leading
      # zeros, so this matches numeric order.
      repo().query!(~S"""
      CREATE OR REPLACE FUNCTION release_semver_sort_key_number(digits text) RETURNS bytea
      LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
      AS $$
        SELECT CASE
          WHEN length(digits) < 255 THEN set_byte('\x00'::bytea, 0, length(digits))
          ELSE '\xff'::bytea || int4send(length(digits))
        END || textsend(digits)
      $$
      """)

      # Comparing two keys bytewise gives SemVer precedence. After the three
      # version numbers, 0xff marks a release without pre-release identifiers
      # so that it sorts after all of its pre-releases. Each pre-release
      # identifier is tagged 0x01 when numeric and 0x02 when alphanumeric, and
      # alphanumeric identifiers end with 0x00. A final 0x00 makes a shorter set
      # of identifiers sort before a longer one that it prefixes. Build metadata
      # does not affect precedence.
      repo().query!(~S"""
      CREATE OR REPLACE FUNCTION release_semver_sort_key(version text) RETURNS bytea
      LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE
      AS $$
      DECLARE
        precedence text := split_part(version, '+', 1);
        separator integer := strpos(precedence, '-');
        identifier text;
        key bytea := '';
      BEGIN
        FOREACH identifier IN ARRAY string_to_array(
          CASE WHEN separator = 0 THEN precedence ELSE left(precedence, separator - 1) END,
          '.'
        ) LOOP
          key := key || release_semver_sort_key_number(identifier);
        END LOOP;

        IF separator = 0 THEN
          RETURN key || '\xff'::bytea;
        END IF;

        FOREACH identifier IN ARRAY string_to_array(substr(precedence, separator + 1), '.') LOOP
          IF identifier ~ '^[0-9]+$' THEN
            key := key || '\x01'::bytea || release_semver_sort_key_number(identifier);
          ELSE
            key := key || '\x02'::bytea || textsend(identifier) || '\x00'::bytea;
          END IF;
        END LOOP;

        RETURN key || '\x00'::bytea;
      END;
      $$
      """)

      repo().query!("""
      CREATE OR REPLACE FUNCTION releases_set_semver_sort_key() RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        NEW.semver_sort_key := release_semver_sort_key(NEW.version);
        NEW.stable := strpos(split_part(NEW.version, '+', 1), '-') = 0;
        RETURN NEW;
      END;
      $$
      """)

      repo().query!("DROP TRIGGER IF EXISTS releases_set_semver_sort_key ON releases")

      repo().query!("""
      CREATE TRIGGER releases_set_semver_sort_key
      BEFORE INSERT OR UPDATE OF version ON releases
      FOR EACH ROW EXECUTE FUNCTION releases_set_semver_sort_key()
      """)

      repo().query!("""
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint
          WHERE conrelid = 'releases'::regclass
            AND conname = 'releases_semver_sort_key_not_null'
        ) THEN
          ALTER TABLE releases
            ADD CONSTRAINT releases_semver_sort_key_not_null
            CHECK (semver_sort_key IS NOT NULL AND stable IS NOT NULL) NOT VALID;
        END IF;
      END;
      $$
      """)
    end)

    backfill(0)

    # Validation scans the table under a lock that still allows reads and
    # writes. The validated constraint then lets SET NOT NULL skip its own scan
    # while it holds ACCESS EXCLUSIVE.
    transaction_with_lock_timeout(fn ->
      repo().query!("ALTER TABLE releases VALIDATE CONSTRAINT releases_semver_sort_key_not_null")
    end)

    transaction_with_lock_timeout(fn ->
      repo().query!("""
      ALTER TABLE releases
        ALTER COLUMN semver_sort_key SET NOT NULL,
        ALTER COLUMN stable SET NOT NULL
      """)

      repo().query!("ALTER TABLE releases DROP CONSTRAINT releases_semver_sort_key_not_null")
    end)
  end

  def down() do
    transaction_with_lock_timeout(fn ->
      repo().query!("DROP TRIGGER IF EXISTS releases_set_semver_sort_key ON releases")
      repo().query!("DROP FUNCTION IF EXISTS releases_set_semver_sort_key()")

      repo().query!("""
      ALTER TABLE releases
        DROP COLUMN IF EXISTS semver_sort_key,
        DROP COLUMN IF EXISTS stable
      """)

      repo().query!("DROP FUNCTION IF EXISTS release_semver_sort_key(text)")
      repo().query!("DROP FUNCTION IF EXISTS release_semver_sort_key_number(text)")
    end)
  end

  # Assigning version to itself fires the trigger, which computes the key once.
  defp backfill(after_id) do
    %{rows: rows} =
      repo().query!(
        """
        WITH batch AS (
          SELECT id FROM releases
          WHERE id > $1 AND semver_sort_key IS NULL
          ORDER BY id
          LIMIT $2
        )
        UPDATE releases SET version = releases.version
        FROM batch
        WHERE releases.id = batch.id
        RETURNING releases.id
        """,
        [after_id, @batch_size],
        log: false
      )

    case rows do
      [] -> :ok
      rows -> rows |> Enum.map(fn [id] -> id end) |> Enum.max() |> backfill()
    end
  end

  defp transaction_with_lock_timeout(fun) do
    {:ok, _} =
      repo().transaction(
        fn ->
          repo().query!("SET LOCAL lock_timeout TO '5s'")
          fun.()
        end,
        timeout: :infinity
      )

    :ok
  end
end
