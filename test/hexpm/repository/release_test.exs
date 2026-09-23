defmodule Hexpm.Repository.ReleaseTest do
  use Hexpm.DataCase, async: true

  alias Hexpm.Repository.Release

  setup do
    publisher = insert(:user)

    [_, _, package3] =
      packages =
      insert_list(3, :package)
      |> Hexpm.Repo.preload(:repository)

    Release.build(
      package3,
      publisher,
      rel_meta(%{version: "0.0.1-dev", app: package3.name}),
      "",
      ""
    )
    |> Hexpm.Repo.insert!()

    %{publisher: publisher, packages: packages}
  end

  test "create release and get", %{publisher: publisher, packages: [package, _, _]} do
    package_id = package.id

    assert %Release{package_id: ^package_id, version: %Version{major: 0, minor: 0, patch: 1}} =
             Release.build(
               package,
               publisher,
               rel_meta(%{version: "0.0.1", app: package.name}),
               "",
               ""
             )
             |> Hexpm.Repo.insert!()

    assert %Release{package_id: ^package_id, version: %Version{major: 0, minor: 0, patch: 1}} =
             Hexpm.Repo.get_by!(assoc(package, :releases), version: "0.0.1")

    Release.build(package, publisher, rel_meta(%{version: "0.0.2", app: package.name}), "", "")
    |> Hexpm.Repo.insert!()

    assert [
             %Release{version: %Version{major: 0, minor: 0, patch: 2}},
             %Release{version: %Version{major: 0, minor: 0, patch: 1}}
           ] = Release.all(package) |> Hexpm.Repo.all() |> Release.sort()
  end

  test "create release and set its publisher", %{publisher: publisher, packages: [package, _, _]} do
    release =
      Release.build(
        package,
        publisher,
        rel_meta(%{publisher_id: publisher.id, version: "0.0.1", app: package.name}),
        "",
        ""
      )
      |> Hexpm.Repo.insert!()

    assert release.publisher_id == publisher.id
  end

  test "update release and update its publisher", %{packages: [package, _, _]} do
    old_publisher = insert(:user)
    new_publisher = insert(:user)

    release =
      Release.build(
        package,
        old_publisher,
        rel_meta(%{version: "0.0.1", app: package.name}),
        "",
        ""
      )
      |> Hexpm.Repo.insert!()

    updated_release =
      release
      |> Map.put(:package, package)
      |> Release.update(new_publisher, %{}, "", "", true)
      |> Hexpm.Repo.update!()

    assert updated_release.publisher_id == new_publisher.id
  end

  test "create release with deps", %{
    publisher: publisher,
    packages: [package1, package2, package3]
  } do
    Release.build(package3, publisher, rel_meta(%{version: "0.0.1", app: package3.name}), "", "")
    |> Hexpm.Repo.insert!()

    Release.build(package3, publisher, rel_meta(%{version: "0.0.2", app: package3.name}), "", "")
    |> Hexpm.Repo.insert!()

    meta =
      rel_meta(%{
        requirements: [
          %{name: package3.name, app: package3.name, requirement: "~> 0.0.1", optional: false}
        ],
        app: package2.name,
        version: "0.0.1"
      })

    Release.build(package2, publisher, meta, "", "") |> Hexpm.Repo.insert!()

    meta =
      rel_meta(%{
        requirements: [
          %{name: package3.name, app: package3.name, requirement: "~> 0.0.2", optional: false},
          %{name: package2.name, app: package2.name, requirement: "== 0.0.1", optional: false}
        ],
        app: package1.name,
        version: "0.0.1"
      })

    Release.build(package1, publisher, meta, "", "") |> Hexpm.Repo.insert!()

    release =
      assoc(package1, :releases)
      |> Hexpm.Repo.get_by!(version: "0.0.1")
      |> Hexpm.Repo.preload(:requirements)

    package2_id = package2.id
    package3_id = package3.id
    package2_name = package2.name
    package3_name = package3.name

    assert [
             %{
               dependency_id: ^package3_id,
               app: ^package3_name,
               requirement: "~> 0.0.2",
               optional: false
             },
             %{
               dependency_id: ^package2_id,
               app: ^package2_name,
               requirement: "== 0.0.1",
               optional: false
             }
           ] = release.requirements
  end

  test "create release in other repository with deps", %{
    publisher: publisher,
    packages: [_, package2, package3]
  } do
    repository = insert(:repository)
    package1_repo = insert(:package, repository_id: repository.id)
    package2_repo = insert(:package, repository_id: repository.id, repository: repository)

    Release.build(
      package1_repo,
      publisher,
      rel_meta(%{version: "0.0.1", app: package1_repo.name}),
      "",
      ""
    )
    |> Hexpm.Repo.insert!()

    Release.build(package2, publisher, rel_meta(%{version: "0.0.1", app: package2.name}), "", "")
    |> Hexpm.Repo.insert!()

    Release.build(package3, publisher, rel_meta(%{version: "0.0.1", app: package3.name}), "", "")
    |> Hexpm.Repo.insert!()

    meta =
      rel_meta(%{
        requirements: [
          %{
            name: package1_repo.name,
            repository: repository.name,
            app: package2_repo.name,
            requirement: "~> 0.0.1",
            optional: false
          },
          %{
            name: package2.name,
            repository: "hexpm",
            app: package2.name,
            requirement: "~> 0.0.1",
            optional: false
          },
          %{name: package3.name, app: package3.name, requirement: "~> 0.0.1", optional: false}
        ],
        app: package2_repo.name,
        version: "0.0.1"
      })

    Release.build(package2_repo, publisher, meta, "", "") |> Hexpm.Repo.insert!()

    release =
      assoc(package2_repo, :releases)
      |> Hexpm.Repo.get_by!(version: "0.0.1")
      |> Hexpm.Repo.preload(:requirements)

    package1_repo_id = package1_repo.id
    package2_id = package2.id
    package3_id = package3.id

    assert [
             %{dependency_id: ^package1_repo_id},
             %{dependency_id: ^package2_id},
             %{dependency_id: ^package3_id}
           ] = release.requirements
  end

  test "create release does not allow deps from other repositories", %{
    publisher: publisher,
    packages: [package1, _, _]
  } do
    repository1 = insert(:repository)
    repository2 = insert(:repository)
    package1_repo = insert(:package, repository_id: repository1.id)
    package2_repo = insert(:package, repository_id: repository2.id)

    package3_repo = insert(:package, repository_id: repository2.id, repository: repository2)

    Release.build(
      package1_repo,
      publisher,
      rel_meta(%{version: "0.0.1", app: package1_repo.name}),
      "",
      ""
    )
    |> Hexpm.Repo.insert!()

    Release.build(
      package2_repo,
      publisher,
      rel_meta(%{version: "0.0.1", app: package2_repo.name}),
      "",
      ""
    )
    |> Hexpm.Repo.insert!()

    package1 = Repo.preload(package1, :repository)

    meta =
      rel_meta(%{
        requirements: [
          %{
            name: package1_repo.name,
            repository: repository1.name,
            app: package1_repo.name,
            requirement: "~> 0.0.1",
            optional: false
          }
        ],
        app: package1.name,
        version: "0.0.1"
      })

    assert %{
             requirements: %{
               repository: "dependencies can only belong to public repository \"hexpm\"" <> _
             }
           } = Release.build(package1, publisher, meta, "", "") |> errors_on()

    meta =
      rel_meta(%{
        requirements: [
          %{
            name: package2_repo.name,
            repository: repository1.name,
            app: package2_repo.name,
            requirement: "~> 0.0.1",
            optional: false
          }
        ],
        app: package1.name,
        version: "0.0.1"
      })

    assert %{
             requirements: %{
               repository: "dependencies can only belong to public repository \"hexpm\"" <> _
             }
           } = Release.build(package1, publisher, meta, "", "") |> errors_on()

    meta =
      rel_meta(%{
        requirements: [
          %{
            name: package1_repo.name,
            repository: "hexpm",
            app: package1_repo.name,
            requirement: "~> 0.0.1",
            optional: false
          }
        ],
        app: package1.name,
        version: "0.0.1"
      })

    assert %{requirements: %{dependency: "package does not exist" <> _}} =
             Release.build(package1, publisher, meta, "", "") |> errors_on()

    meta =
      rel_meta(%{
        requirements: [
          %{
            name: package1_repo.name,
            app: package1_repo.name,
            requirement: "~> 0.0.1",
            optional: false
          }
        ],
        app: package1.name,
        version: "0.0.1"
      })

    assert %{requirements: %{dependency: "package does not exist" <> _}} =
             Release.build(package1, publisher, meta, "", "") |> errors_on()

    meta =
      rel_meta(%{
        requirements: [
          %{
            name: package2_repo.name,
            repository: "hexpm",
            app: package2_repo.name,
            requirement: "~> 0.0.1",
            optional: false
          }
        ],
        app: package1.name,
        version: "0.0.1"
      })

    assert %{requirements: %{dependency: "package does not exist" <> _}} =
             Release.build(package3_repo, publisher, meta, "", "") |> errors_on()

    meta =
      rel_meta(%{
        requirements: [
          %{
            name: package2_repo.name,
            app: package2_repo.name,
            requirement: "~> 0.0.1",
            optional: false
          }
        ],
        app: package1.name,
        version: "0.0.1"
      })

    assert %{requirements: %{dependency: "package does not exist" <> _}} =
             Release.build(package3_repo, publisher, meta, "", "") |> errors_on()
  end

  test "validate release", %{publisher: publisher, packages: [_, package2, package3]} do
    Release.build(
      package3,
      publisher,
      rel_meta(%{version: "0.1.0", app: package3.name, requirements: []}),
      "",
      ""
    )
    |> Hexpm.Repo.insert!()

    reqs = [%{name: package3.name, app: package3.name, requirement: "~> 0.1", optional: false}]

    Release.build(
      package2,
      publisher,
      rel_meta(%{version: "0.1.0", app: package2.name, requirements: reqs}),
      "",
      ""
    )
    |> Hexpm.Repo.insert!()

    meta = %{"version" => "0.1.0", "requirements" => [], "build_tools" => ["mix"]}

    assert %{meta: %{app: "can't be blank"}} =
             Release.build(package3, publisher, %{"meta" => meta}, "", "") |> errors_on()

    meta = %{"app" => package3.name, "version" => "0.1.0", "requirements" => []}

    assert %{meta: %{build_tools: "can't be blank"}} =
             Release.build(package3, publisher, %{"meta" => meta}, "", "") |> errors_on()

    meta = %{
      "app" => package3.name,
      "version" => "0.1.0",
      "requirements" => [],
      "build_tools" => []
    }

    assert %{meta: %{build_tools: "can't be blank"}} =
             Release.build(package3, publisher, %{"meta" => meta}, "", "") |> errors_on()

    meta = %{
      "app" => package3.name,
      "version" => "0.1.0",
      "requirements" => [],
      "build_tools" => ["mix"],
      "elixir" => "== == 0.0.1"
    }

    assert %{meta: %{elixir: "invalid requirement: \"== == 0.0.1\""}} =
             Release.build(package3, publisher, %{"meta" => meta}, "", "") |> errors_on()

    assert %{version: "is invalid SemVer"} =
             Release.build(
               package2,
               publisher,
               rel_meta(%{version: "0.1", app: package2.name}),
               "",
               ""
             )
             |> errors_on()

    reqs = [%{name: package3.name, app: package3.name, requirement: "~> fail", optional: false}]

    assert %{requirements: %{requirement: "invalid requirement: \"~> fail\""}} =
             Release.build(
               package2,
               publisher,
               rel_meta(%{version: "0.1.1", app: package2.name, requirements: reqs}),
               "",
               ""
             )
             |> errors_on()

    meta = %{
      "app" => package3.name,
      "version" => "0.1.0",
      "requirements" => [],
      "build_tools" => ["mix"],
      "files" => []
    }

    assert %{meta: %{files: "package can't be empty"}} =
             Release.build(package3, publisher, %{"meta" => meta}, "", "") |> errors_on()
  end

  test "ensure unique build tools", %{publisher: publisher, packages: [_, _, package3]} do
    changeset =
      Release.build(
        package3,
        publisher,
        rel_meta(%{version: "0.1.0", app: package3.name, build_tools: ["mix", "make", "make"]}),
        "",
        ""
      )

    assert changeset.changes.meta.changes.build_tools == ["mix", "make"]
  end

  test "release version is unique", %{publisher: publisher, packages: [package1, package2, _]} do
    Release.build(package1, publisher, rel_meta(%{version: "0.0.1", app: package1.name}), "", "")
    |> Hexpm.Repo.insert!()

    Release.build(package2, publisher, rel_meta(%{version: "0.0.1", app: package2.name}), "", "")
    |> Hexpm.Repo.insert!()

    assert {:error, %{errors: [version: {"has already been published", _}]}} =
             Release.build(
               package1,
               publisher,
               rel_meta(%{version: "0.0.1", app: package1.name}),
               "",
               ""
             )
             |> Hexpm.Repo.insert()
  end

  test "update release", %{publisher: publisher, packages: [_, package2, package3]} do
    Release.build(package3, publisher, rel_meta(%{version: "0.0.1", app: package3.name}), "", "")
    |> Hexpm.Repo.insert!()

    reqs = [%{name: package3.name, app: package3.name, requirement: "~> 0.0.1", optional: false}]

    release =
      Release.build(
        package2,
        publisher,
        rel_meta(%{version: "0.0.1", app: package2.name, requirements: reqs}),
        "",
        ""
      )
      |> Hexpm.Repo.insert!()

    params =
      params(%{
        app: package2.name,
        requirements: [
          %{name: package3.name, app: package3.name, requirement: ">= 0.0.1", optional: false}
        ]
      })

    Release.update(%{release | package: package2}, publisher, params, "", "", true)
    |> Hexpm.Repo.update!()

    package3_id = package3.id
    package3_name = package3.name

    release =
      assoc(package2, :releases)
      |> Hexpm.Repo.get_by!(version: "0.0.1")
      |> Hexpm.Repo.preload(:requirements)

    assert [
             %{
               dependency_id: ^package3_id,
               app: ^package3_name,
               requirement: ">= 0.0.1",
               optional: false
             }
           ] = release.requirements
  end

  test "update release fails with invalid version", %{
    publisher: publisher,
    packages: [_, package2, package3]
  } do
    Release.build(package3, publisher, rel_meta(%{version: "0.0.1", app: package3.name}), "", "")
    |> Hexpm.Repo.insert!()

    reqs = [%{name: package3.name, app: package3.name, requirement: "~> 0.0.1", optional: false}]

    release =
      Release.build(
        package2,
        publisher,
        rel_meta(%{version: "0.0.1", app: package2.name, requirements: reqs}),
        "",
        ""
      )
      |> Hexpm.Repo.insert!()

    params =
      params(%{
        app: package2.name,
        version: "1.0"
      })

    changeset = Release.update(%{release | package: package2}, publisher, params, "", "", true)
    assert [version: {"is invalid SemVer", _}] = changeset.errors
  end

  test "delete release", %{publisher: publisher, packages: [_, package2, package3]} do
    release =
      Release.build(
        package3,
        publisher,
        rel_meta(%{version: "0.0.1", app: package3.name}),
        "",
        ""
      )
      |> Hexpm.Repo.insert!()
      |> Map.put(:package, package3)

    Release.delete(release) |> Hexpm.Repo.delete!()
    refute Hexpm.Repo.get_by(assoc(package2, :releases), version: "0.0.1")
  end

  test "latest_version" do
    package = insert(:package)

    insert(
      :release,
      package: package,
      version: "0.0.1",
      meta: build(:release_metadata, app: package.name),
      has_docs: true
    )

    insert(
      :release,
      package: package,
      version: "0.0.2",
      meta: build(:release_metadata, app: package.name),
      has_docs: false
    )

    insert(
      :release,
      package: package,
      version: %Version{major: 0, minor: 0, patch: 3, pre: ["dev", 0, 1]},
      meta: build(:release_metadata, app: package.name),
      has_docs: true
    )

    assert %Release{version: %Version{major: 0, minor: 0, patch: 2}} =
             Release.all(package) |> Hexpm.Repo.all() |> Release.latest_version(only_stable: true)

    assert %Release{version: %Version{major: 0, minor: 0, patch: 1}} =
             Release.all(package)
             |> Hexpm.Repo.all()
             |> Release.latest_version(only_stable: true, with_docs: true)
  end

  test "semver_sort_key orders releases by SemVer precedence" do
    package = insert(:package)
    long = String.duplicate("9", 300)
    long_versions = ["1.0.0-#{long}", "1.0.0-1#{String.duplicate("0", 300)}", "#{long}.0.0"]

    versions = ~w(
      0.0.1 0.0.2 0.1.0 0.9.0 0.10.0 1.0.0-0 1.0.0-2 1.0.0-10 1.0.0-0a 1.0.0-A
      1.0.0-a 1.0.0-alpha 1.0.0-alpha-1 1.0.0-alpha.1 1.0.0-alpha.1.0 1.0.0-alpha.beta
      1.0.0-alpha0 1.0.0-beta 1.0.0-beta.2 1.0.0-beta.11 1.0.0-rc.1 1.0.0 1.0.1-rc.1+build-1
      1.0.1 2.0.0 9.0.0 10.0.0 123456789012345678901234567890.0.0
    ) ++ long_versions

    for version <- Enum.shuffle(versions) do
      insert(:release, package: package, version: version)
    end

    keyed =
      from(r in Release,
        where: r.package_id == ^package.id,
        order_by: r.semver_sort_key,
        select: r.version
      )
      |> Hexpm.Repo.all()

    assert keyed == versions |> Enum.map(&Version.parse!/1) |> Enum.sort(Version)
  end

  test "stable and semver_sort_key follow version changes" do
    package = insert(:package)
    release = insert(:release, package: package, version: "1.0.0-rc.1")

    stored = fn ->
      from(r in Release, where: r.id == ^release.id, select: {r.stable, r.semver_sort_key})
      |> Hexpm.Repo.one!()
    end

    assert {false, rc_key} = stored.()

    release
    |> Ecto.Changeset.change(version: Version.parse!("1.0.0+build.1"))
    |> Hexpm.Repo.update!()

    assert {true, stable_key} = stored.()
    assert stable_key > rc_key
  end

  test "latest/2 selects the same release as latest_version/2" do
    package = insert(:package)

    for {version, has_docs} <- [
          {"0.0.1", true},
          {"0.0.2", false},
          {"0.0.3-dev.0.1", true},
          {"0.0.10-rc.1", false}
        ] do
      insert(:release,
        package: package,
        version: version,
        has_docs: has_docs,
        meta: build(:release_metadata, app: package.name)
      )
    end

    prerelease_package = insert(:package)

    for version <- ["1.0.0-rc.1", "1.0.0-rc.2"] do
      insert(:release, package: prerelease_package, version: version)
    end

    for opts <- [
          [only_stable: false],
          [only_stable: true],
          [only_stable: true, unstable_fallback: true],
          [only_stable: false, with_docs: true],
          [only_stable: true, with_docs: true],
          [only_stable: true, unstable_fallback: true, with_docs: true]
        ],
        subject <- [package, prerelease_package] do
      expected = Release.all(subject) |> Hexpm.Repo.all() |> Release.latest_version(opts)
      latest = Release.all(subject) |> Release.latest(opts) |> Hexpm.Repo.one()

      assert (latest && latest.id) == (expected && expected.id), inspect(opts)
    end
  end
end
