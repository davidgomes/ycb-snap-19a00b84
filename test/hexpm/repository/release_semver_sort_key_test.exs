defmodule Hexpm.Repository.ReleaseSemverSortKeyTest do
  use Hexpm.DataCase, async: true

  alias Hexpm.Repository.Release

  property "sorts keys by SemVer precedence" do
    check all(versions <- list_of(version(), min_length: 2, max_length: 20)) do
      keyed = Enum.zip(versions, semver_keys(versions))

      for {version1, {key1, _}} <- keyed, {version2, {key2, _}} <- keyed do
        assert compare(key1, key2) == Version.compare(version1, version2),
               "#{version1} vs #{version2}"
      end

      for {version, {_, stable}} <- keyed do
        assert stable == (Version.parse!(version).pre == [])
      end
    end
  end

  test "sorts numbers numerically and identifiers per SemVer" do
    versions = [
      "1.0.0-0",
      "1.0.0-1",
      "1.0.0-2",
      "1.0.0-10",
      "1.0.0--",
      "1.0.0-0a",
      "1.0.0-A",
      "1.0.0-alpha",
      "1.0.0-alpha.1",
      "1.0.0-alpha.beta",
      "1.0.0-beta",
      "1.0.0-beta.2",
      "1.0.0-beta.11",
      "1.0.0-rc.1",
      "1.0.0",
      "1.0.1",
      "1.9.0",
      "1.10.0",
      "10.0.0",
      "99999999999999.0.0"
    ]

    sorted =
      versions
      |> Enum.zip(semver_keys(versions))
      |> Enum.sort_by(fn {_version, {key, _stable}} -> key end)
      |> Enum.map(fn {version, _key} -> version end)

    assert sorted == versions
  end

  test "ignores build metadata" do
    assert [{key, false}, {key, false}] = semver_keys(["1.0.0-rc.1", "1.0.0-rc.1+build.5"])
  end

  test "rejects invalid versions" do
    for version <- ["1.0", "01.0.0", "1.0.0-01", "1.0.0-", "1.0.0-a..b", "1.0.0+", "v1.0.0"] do
      assert_raise Postgrex.Error, ~r/invalid SemVer version/, fn -> semver_keys([version]) end
    end
  end

  test "trigger sets the key on insert and when the version changes" do
    release = insert(:release, package: insert(:package), version: "1.0.0-rc.1")

    assert stored_semver_key(release) == hd(semver_keys(["1.0.0-rc.1"]))

    release
    |> Ecto.Changeset.change(version: Version.parse!("1.0.0"))
    |> Repo.update!()

    assert stored_semver_key(release) == hd(semver_keys(["1.0.0"]))
  end

  defp version() do
    gen all(
          major <- number(),
          minor <- number(),
          patch <- number(),
          pre <- list_of(identifier(), max_length: 4),
          build <- member_of(["", "+build.1"])
        ) do
      pre = if pre == [], do: "", else: "-" <> Enum.join(pre, ".")
      "#{major}.#{minor}.#{patch}#{pre}#{build}"
    end
  end

  # Mostly small numbers so that versions often share a prefix.
  defp number() do
    frequency([{4, integer(0..2)}, {1, integer(0..99_999_999_999_999)}])
  end

  defp identifier() do
    frequency([
      {2, map(number(), &Integer.to_string/1)},
      {2, member_of(~w(alpha beta rc a A - 0a))},
      {1,
       string([?0..?9, ?a..?z, ?A..?Z, ?-], min_length: 1, max_length: 4)
       |> filter(&(&1 =~ ~r/[^0-9]/))}
    ])
  end

  defp semver_keys(versions) do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT k.sort_key, k.stable
        FROM unnest($1::text[]) WITH ORDINALITY AS v(version, i), semver_key(v.version) AS k
        ORDER BY v.i
        """,
        [versions]
      )

    Enum.map(rows, &List.to_tuple/1)
  end

  defp stored_semver_key(release) do
    Repo.one!(
      from(r in Release, where: r.id == ^release.id, select: {r.semver_sort_key, r.stable})
    )
  end

  defp compare(key1, key2) when key1 < key2, do: :lt
  defp compare(key1, key2) when key1 > key2, do: :gt
  defp compare(_key1, _key2), do: :eq
end
