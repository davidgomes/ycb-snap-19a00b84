defmodule Hexpm.Repository.Policy.RepositoryPolicyTest do
  use Hexpm.DataCase, async: true

  alias Hexpm.Repository.Policy.{Override, RepositoryPolicy}

  defp changeset(attrs) do
    RepositoryPolicy.changeset(%RepositoryPolicy{}, attrs)
  end

  test "requires a repository" do
    refute changeset(%{}).valid?
    assert errors_on(changeset(%{})).repository == "can't be blank"
  end

  test "accepts a bare repository tab" do
    assert changeset(%{"repository" => "hexpm"}).valid?
  end

  test "validates advisory_min_severity range 0..4" do
    cs = changeset(%{"repository" => "hexpm", "advisory_min_severity" => 5})
    refute cs.valid?
    assert errors_on(cs).advisory_min_severity == "must be less than or equal to 4"
  end

  test "validates retirement_reasons elements in 0..4" do
    cs = changeset(%{"repository" => "hexpm", "retirement_reasons" => [1, 99]})
    refute cs.valid?
    assert errors_on(cs).retirement_reasons == "contains invalid reasons"
  end

  test "validates cooldown duration format" do
    refute changeset(%{"repository" => "hexpm", "cooldown" => "5x"}).valid?
    assert changeset(%{"repository" => "hexpm", "cooldown" => "14d"}).valid?
  end

  test "blank cooldown is nilified" do
    cs = changeset(%{"repository" => "hexpm", "cooldown" => ""})
    assert cs.valid?
    assert Ecto.Changeset.apply_changes(cs).cooldown == nil
  end

  test "rejects the same override package listed twice" do
    cs =
      changeset(%{
        "repository" => "hexpm",
        "overrides" => [
          %{"action" => "allow", "package" => "phoenix"},
          %{"action" => "deny", "package" => "phoenix"}
        ]
      })

    refute cs.valid?
    assert errors_on(cs).overrides == "list the same package more than once"
  end

  test "allows the same package across different repository tabs" do
    # uniqueness is per-tab, so two tabs may each reference the package
    cs1 =
      changeset(%{
        "repository" => "hexpm",
        "overrides" => [%{"action" => "deny", "package" => "phoenix"}]
      })

    cs2 =
      changeset(%{
        "repository" => "myorg",
        "overrides" => [%{"action" => "deny", "package" => "phoenix"}]
      })

    assert cs1.valid?
    assert cs2.valid?
  end

  describe "removing overrides" do
    setup do
      tab = %RepositoryPolicy{
        repository: "hexpm",
        overrides: [
          %Override{id: Ecto.UUID.generate(), action: :deny, package: "badlib"},
          %Override{id: Ecto.UUID.generate(), action: :allow, package: "phoenix"}
        ]
      }

      %{tab: tab}
    end

    test "a drop param without overrides clears every override", %{tab: tab} do
      cs = RepositoryPolicy.changeset(tab, %{"overrides_drop" => [""]})

      assert cs.valid?
      assert Ecto.Changeset.apply_changes(cs).overrides == []
    end

    test "keeps only the submitted overrides", %{tab: tab} do
      [_badlib, phoenix] = tab.overrides

      cs =
        RepositoryPolicy.changeset(tab, %{
          "overrides" => %{
            "1" => %{"id" => phoenix.id, "action" => "allow", "package" => "phoenix"}
          },
          "overrides_drop" => [""]
        })

      assert cs.valid?
      assert [%Override{package: "phoenix"}] = Ecto.Changeset.apply_changes(cs).overrides
    end

    test "leaves overrides untouched when neither param is submitted", %{tab: tab} do
      cs = RepositoryPolicy.changeset(tab, %{"cooldown" => "7d"})

      assert cs.valid?
      assert length(Ecto.Changeset.apply_changes(cs).overrides) == 2
    end
  end
end
