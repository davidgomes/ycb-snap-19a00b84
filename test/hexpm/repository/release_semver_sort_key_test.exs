defmodule Hexpm.Repository.ReleaseSemverSortKeyTest do
  use Hexpm.DataCase, async: true

  alias Hexpm.Repository.Release

  @ordered [
    "0.9.0",
    "0.10.0",
    "1.0.0-0",
    "1.0.0-2",
    "1.0.0-10",
    "1.0.0--",
    "1.0.0-A",
    "1.0.0-a",
    "1.0.0-alpha",
    "1.0.0-alpha.1",
    "1.0.0-alpha.beta",
    "1.0.0-alpha-1",
    "1.0.0-beta",
    "1.0.0-beta.2",
    "1.0.0-beta.11",
    "1.0.0-rc.1",
    "1.0.0",
    "1.0.1",
    "1.1.0",
    "2.0.0",
    "10.0.0",
    "#{Integer.pow(10, 253)}.0.0",
    "#{Integer.pow(10, 254)}.0.0",
    "#{Integer.pow(10, 300)}.0.0"
  ]

  test "the database orders keys by SemVer precedence" do
    assert Enum.sort(@ordered, Version) == @ordered

    %{rows: rows} =
      Repo.query!(
        """
        SELECT version FROM unnest($1::text[]) AS version
        ORDER BY (semver_sort_key(version)).sort_key
        """,
        [Enum.shuffle(@ordered)]
      )

    assert List.flatten(rows) == @ordered
  end

  property "keys compare like Version.compare/2" do
    check all(versions <- list_of(version(), min_length: 2, max_length: 20)) do
      keys = keys(versions)

      for left <- versions, right <- versions do
        assert compare(keys[left].sort_key, keys[right].sort_key) == Version.compare(left, right),
               "#{left} vs #{right}"
      end

      for version <- versions do
        assert keys[version].stable == (Version.parse!(version).pre == [])
      end
    end
  end

  test "ignores build metadata" do
    keys = keys(["1.0.0", "1.0.0+build.1", "1.0.0-rc.1", "1.0.0-rc.1+build-2"])

    assert keys["1.0.0+build.1"] == keys["1.0.0"]
    assert keys["1.0.0-rc.1+build-2"] == keys["1.0.0-rc.1"]
  end

  test "rejects versions that aren't SemVer" do
    for version <- ["", "1", "1.0", "1.0.0.0", "01.0.0", "v1.0.0", "1.0.0-", "1.0.0-01"] ++
                     ["1.0.0-a..b", "1.0.0-a.", "1.0.0-a_b"] do
      assert Version.parse(version) == :error

      assert_raise Postgrex.Error, ~r/invalid SemVer version/, fn ->
        Repo.transaction(fn -> keys([version]) end)
      end
    end
  end

  test "keeps a release's key in sync with its version" do
    release = insert(:release, package: insert(:package), version: "1.0.0-rc.1")

    assert stored_key(release) == keys(["1.0.0-rc.1"])["1.0.0-rc.1"]

    release
    |> Ecto.Changeset.change(version: Version.parse!("1.0.0"))
    |> Repo.update!()

    assert stored_key(release) == keys(["1.0.0"])["1.0.0"]
  end

  defp keys(versions) do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT version, key.sort_key, key.stable
        FROM unnest($1::text[]) AS version, semver_sort_key(version) AS key
        """,
        [versions]
      )

    Map.new(rows, fn [version, sort_key, stable] ->
      {version, %{sort_key: sort_key, stable: stable}}
    end)
  end

  defp stored_key(release) do
    Repo.one!(
      from(r in Release,
        where: r.id == ^release.id,
        select: %{sort_key: r.semver_sort_key, stable: r.stable}
      )
    )
  end

  defp compare(left, right) when left < right, do: :lt
  defp compare(left, right) when left > right, do: :gt
  defp compare(_left, _right), do: :eq

  defp version() do
    gen all(
          major <- number(),
          minor <- number(),
          patch <- number(),
          pre <- list_of(identifier(), max_length: 3)
        ) do
      core = Enum.join([major, minor, patch], ".")
      if pre == [], do: core, else: core <> "-" <> Enum.join(pre, ".")
    end
  end

  # Numbers with 251 to 261 digits cross the 255-digit boundary where the key
  # switches to a four-byte length.
  defp number() do
    frequency([
      {6, integer(0..3)},
      {3, non_negative_integer()},
      {1, map(integer(250..260), &Integer.pow(10, &1))}
    ])
    |> map(&Integer.to_string/1)
  end

  defp identifier() do
    one_of([
      number(),
      string([?0..?2, ?a..?b, ?A, ?-], min_length: 1, max_length: 3)
      |> filter(&(not String.match?(&1, ~r/^0[0-9]+$/)))
    ])
  end
end
