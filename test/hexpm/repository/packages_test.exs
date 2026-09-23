defmodule Hexpm.Repository.PackagesTest do
  use Hexpm.DataCase, async: true

  alias Hexpm.Repository.Packages

  test "public_names/0 returns sorted public package names" do
    insert(:package, name: "z_package")
    insert(:package, name: "a_package")

    private_repository = insert(:repository, name: "private")
    insert(:package, name: "private_package", repository_id: private_repository.id)

    names = Packages.public_names()

    assert Enum.sort(names) == names
    assert "a_package" in names
    assert "z_package" in names
    refute "private_package" in names
  end

  test "attach_latest_releases/1 prefers stable releases and falls back to prereleases" do
    stable_package = insert(:package)
    insert(:release, package: stable_package, version: "0.9.0")
    stable = insert(:release, package: stable_package, version: "0.10.0")
    insert(:release, package: stable_package, version: "1.0.0-rc.1")

    prerelease_package = insert(:package)
    insert(:release, package: prerelease_package, version: "1.0.0-rc.2")
    insert(:release, package: prerelease_package, version: "1.0.0-rc.10")

    empty_package = insert(:package)

    assert [stable_result, prerelease_result, empty_result] =
             Packages.attach_latest_releases([stable_package, prerelease_package, empty_package])

    assert stable_result.latest_release.version == Version.parse!("0.10.0")
    assert stable_result.latest_release.inserted_at == stable.inserted_at
    assert prerelease_result.latest_release.version == Version.parse!("1.0.0-rc.10")
    assert empty_result.latest_release == nil
  end
end
