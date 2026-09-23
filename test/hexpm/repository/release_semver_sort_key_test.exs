defmodule Hexpm.Repository.ReleaseSemverSortKeyTest do
  use Hexpm.DataCase, async: true

  alias Hexpm.Repository.Release

  @spec_order ~w(
    1.0.0-alpha
    1.0.0-alpha.1
    1.0.0-alpha.beta
    1.0.0-beta
    1.0.0-beta.2
    1.0.0-beta.11
    1.0.0-rc.1
    1.0.0
    2.0.0
    2.1.0
    2.1.1
  )

  defp sort_by_key(versions) do
    %{rows: rows} =
      Repo.query!("SELECT v FROM unnest($1::text[]) v ORDER BY semver_sort_key(v)", [versions])

    Enum.map(rows, fn [version] -> version end)
  end

  defp sort_key(version) do
    %{rows: [[key]]} = Repo.query!("SELECT semver_sort_key($1)", [version])
    key
  end

  defp package_versions(package, opts) do
    from(r in Release, where: r.package_id == ^package.id, select: r.version)
    |> Release.order_by_latest(opts)
    |> Repo.all()
    |> Enum.map(&to_string/1)
  end

  defp random_number() do
    case :rand.uniform(4) do
      1 -> :rand.uniform(3) - 1
      2 -> :rand.uniform(20) - 1
      3 -> :rand.uniform(1_000_000_000_000)
      4 -> String.to_integer("1" <> String.duplicate("7", 254 + :rand.uniform(10)))
    end
  end

  defp random_identifier() do
    if :rand.uniform(2) == 1 do
      Integer.to_string(random_number())
    else
      for(_ <- 1..:rand.uniform(4), into: "", do: <<Enum.random(~c"aAbz-")>>)
    end
  end

  defp random_version() do
    core = Enum.map_join(1..3, ".", fn _ -> random_number() end)

    if :rand.uniform(3) == 1 do
      core
    else
      core <> "-" <> Enum.map_join(1..:rand.uniform(4), ".", fn _ -> random_identifier() end)
    end
  end

  test "orders the SemVer specification examples" do
    assert sort_by_key(Enum.shuffle(@spec_order)) == @spec_order
  end

  test "orders like Version.compare/2" do
    :rand.seed(:exsss, {1, 8, 32})

    versions =
      Stream.repeatedly(&random_version/0)
      |> Stream.uniq()
      |> Enum.take(2000)

    assert Enum.all?(versions, &match?({:ok, _}, Version.parse(&1)))
    assert sort_by_key(versions) == Enum.sort(versions, Version)
  end

  test "compares numbers numerically and ignores build metadata" do
    assert sort_by_key(~w(10.0.0 9.0.0 1.10.0 1.9.0 1.0.0-rc.10 1.0.0-rc.9)) ==
             ~w(1.0.0-rc.9 1.0.0-rc.10 1.9.0 1.10.0 9.0.0 10.0.0)

    assert sort_key("1.0.0-rc.1+build.1") == sort_key("1.0.0-rc.1")
  end

  test "rejects versions that aren't SemVer" do
    for version <- ~w(1.0 01.0.0 1.0.0- 1.0.0-01 1.0.0-a..b 1.0.0+ v1.0.0) do
      assert_raise Postgrex.Error, ~r/invalid SemVer version/, fn -> sort_key(version) end
    end
  end

  test "orders releases latest first" do
    package = insert(:package)

    for version <- Enum.shuffle(~w(0.9.0 0.10.0 1.0.0-rc.1 0.11.0-dev)) do
      insert(:release, package: package, version: version)
    end

    assert package_versions(package, only_stable: false) ==
             ~w(1.0.0-rc.1 0.11.0-dev 0.10.0 0.9.0)

    assert package_versions(package, only_stable: true) == ~w(0.10.0 0.9.0)

    assert package_versions(package, only_stable: true, unstable_fallback: true) ==
             ~w(0.10.0 0.9.0 1.0.0-rc.1 0.11.0-dev)
  end

  test "recomputes the key when the version changes" do
    package = insert(:package)
    insert(:release, package: package, version: "1.0.0")
    release = insert(:release, package: package, version: "2.0.0-rc.1")

    release
    |> Ecto.Changeset.change(version: Version.parse!("0.1.0"))
    |> Repo.update!()

    assert package_versions(package, only_stable: false) == ~w(1.0.0 0.1.0)
    assert package_versions(package, only_stable: true) == ~w(1.0.0 0.1.0)
  end
end
