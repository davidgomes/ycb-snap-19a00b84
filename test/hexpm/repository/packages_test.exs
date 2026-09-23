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

  test "attach_latest_releases/1 attaches the latest stable release or else the latest pre-release" do
    stable = insert(:package)
    insert(:release, package: stable, version: "1.9.0")
    insert(:release, package: stable, version: "1.10.0")
    insert(:release, package: stable, version: "2.0.0-rc.1")

    prerelease = insert(:package)
    insert(:release, package: prerelease, version: "1.0.0-rc.9")
    insert(:release, package: prerelease, version: "1.0.0-rc.10")

    unreleased = insert(:package)

    assert [stable, prerelease, unreleased] =
             Packages.attach_latest_releases([stable, prerelease, unreleased])

    assert stable.latest_release.version == Version.parse!("1.10.0")
    assert stable.latest_release.inserted_at
    assert prerelease.latest_release.version == Version.parse!("1.0.0-rc.10")
    assert unreleased.latest_release == nil
  end
end
