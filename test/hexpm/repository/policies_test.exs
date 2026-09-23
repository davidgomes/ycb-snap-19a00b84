defmodule Hexpm.Repository.PoliciesTest do
  use Hexpm.DataCase, async: false

  alias Hexpm.Repository.{Policies, Policy}

  setup do
    user = insert(:user)
    organization = insert(:organization)
    audit_data = audit_data(user)
    %{user: user, organization: organization, audit_data: audit_data}
  end

  defp tab(policy, repository) do
    Enum.find(policy.repositories, &(&1.repository == repository))
  end

  defp policy_with_overrides(org, audit_data, packages) do
    {:ok, %{policy: policy}} =
      Policies.create(
        org,
        %{
          "name" => "pol1",
          "visibility" => "public",
          "repositories" => [
            %{
              "repository" => "hexpm",
              "overrides" => Enum.map(packages, &%{"action" => "deny", "package" => &1})
            }
          ]
        },
        audit: audit_data
      )

    policy
  end

  defp override_params(override) do
    %{
      "id" => override.id,
      "action" => to_string(override.action),
      "package" => override.package,
      "requirement" => override.requirement || ""
    }
  end

  describe "create/3" do
    test "seeds a hexpm tab and the org tab", %{organization: org, audit_data: audit_data} do
      params = %{"name" => "strict-prod", "visibility" => "public"}

      assert {:ok, %{policy: policy}} = Policies.create(org, params, audit: audit_data)
      assert policy.name == "strict-prod"
      assert policy.organization_id == org.id
      assert Enum.map(policy.repositories, & &1.repository) == ["hexpm", org.name]
    end

    test "stores per-repository restrictions", %{organization: org, audit_data: audit_data} do
      params = %{
        "name" => "strict-prod",
        "visibility" => "private",
        "repositories" => [
          %{"repository" => "hexpm", "cooldown" => "14d"},
          %{"repository" => org.name}
        ]
      }

      assert {:ok, %{policy: policy}} = Policies.create(org, params, audit: audit_data)
      assert tab(policy, "hexpm").cooldown == "14d"
      assert tab(policy, org.name).cooldown == nil
    end

    test "returns changeset error for invalid params",
         %{organization: org, audit_data: audit_data} do
      assert {:error, :policy, changeset, _} =
               Policies.create(org, %{"name" => "ab"}, audit: audit_data)

      refute changeset.valid?
    end

    test "writes a policy.create audit log entry",
         %{organization: org, audit_data: audit_data} do
      {:ok, _} =
        Policies.create(org, %{"name" => "strict-prod", "visibility" => "public"},
          audit: audit_data
        )

      assert [%Hexpm.Accounts.AuditLog{action: "policy.create", params: params}] =
               Hexpm.Repo.all(Hexpm.Accounts.AuditLog)

      assert params["name"] == "strict-prod"
      assert hd(Hexpm.Repo.all(Hexpm.Accounts.AuditLog)).organization_id == org.id
    end
  end

  describe "update/3" do
    test "updates visibility and per-repository restrictions",
         %{organization: org, audit_data: audit_data} do
      {:ok, %{policy: policy}} =
        Policies.create(org, %{"name" => "pol1", "visibility" => "public"}, audit: audit_data)

      params = %{
        "visibility" => "private",
        "repositories" => [
          %{"repository" => "hexpm", "cooldown" => "7d"},
          %{"repository" => org.name}
        ]
      }

      assert {:ok, %{policy: updated}} = Policies.update(policy, params, audit: audit_data)

      assert updated.visibility == "private"
      assert tab(updated, "hexpm").cooldown == "7d"
    end

    test "preserves tabs when repositories are not submitted",
         %{organization: org, audit_data: audit_data} do
      {:ok, %{policy: policy}} =
        Policies.create(
          org,
          %{
            "name" => "pol1",
            "visibility" => "public",
            "repositories" => [%{"repository" => "hexpm", "cooldown" => "14d"}]
          },
          audit: audit_data
        )

      {:ok, %{policy: updated}} =
        Policies.update(policy, %{"description" => "updated"}, audit: audit_data)

      assert tab(updated, "hexpm").cooldown == "14d"
    end

    test "removes every override when a tab submits none",
         %{organization: org, audit_data: audit_data} do
      policy = policy_with_overrides(org, audit_data, ["badlib"])
      hexpm = tab(policy, "hexpm")

      params = %{
        "repositories" => %{
          "0" => %{"id" => hexpm.id, "repository" => "hexpm", "cooldown" => ""},
          "1" => %{"id" => tab(policy, org.name).id, "repository" => org.name}
        }
      }

      {:ok, %{policy: updated}} = Policies.update(policy, params, audit: audit_data)

      assert tab(updated, "hexpm").overrides == []
    end

    test "removes overrides whose rows were dropped from the form",
         %{organization: org, audit_data: audit_data} do
      policy = policy_with_overrides(org, audit_data, ["badlib", "worselib", "phoenix"])
      hexpm = tab(policy, "hexpm")
      [badlib, worselib, phoenix] = hexpm.overrides

      params = %{
        "repositories" => %{
          "0" => %{
            "id" => hexpm.id,
            "repository" => "hexpm",
            "overrides" => %{
              "0" => override_params(badlib),
              "1" => %{"id" => worselib.id},
              "2" => override_params(phoenix)
            }
          },
          "1" => %{"id" => tab(policy, org.name).id, "repository" => org.name}
        }
      }

      {:ok, %{policy: updated}} = Policies.update(policy, params, audit: audit_data)

      assert Enum.map(tab(updated, "hexpm").overrides, & &1.package) == ["badlib", "phoenix"]
    end

    test "keeps new override rows after existing ones",
         %{organization: org, audit_data: audit_data} do
      policy = policy_with_overrides(org, audit_data, ["a1", "a2", "a3"])
      hexpm = tab(policy, "hexpm")
      [a1, a2, a3] = hexpm.overrides

      params = %{
        "repositories" => %{
          "0" => %{
            "id" => hexpm.id,
            "repository" => "hexpm",
            "overrides" => %{
              "0" => override_params(a1),
              "1" => override_params(a2),
              "2" => override_params(a3),
              "100000" => %{"action" => "deny", "package" => "b1"}
            }
          },
          "1" => %{"id" => tab(policy, org.name).id, "repository" => org.name}
        }
      }

      {:ok, %{policy: updated}} = Policies.update(policy, params, audit: audit_data)

      assert Enum.map(tab(updated, "hexpm").overrides, & &1.package) == ["a1", "a2", "a3", "b1"]
    end

    test "keeps overrides when repositories are not submitted",
         %{organization: org, audit_data: audit_data} do
      policy = policy_with_overrides(org, audit_data, ["badlib"])

      {:ok, %{policy: updated}} =
        Policies.update(policy, %{"description" => "updated"}, audit: audit_data)

      assert Enum.map(tab(updated, "hexpm").overrides, & &1.package) == ["badlib"]
    end

    test "writes a policy.update audit log entry",
         %{organization: org, audit_data: audit_data} do
      {:ok, %{policy: policy}} =
        Policies.create(org, %{"name" => "pol1", "visibility" => "public"}, audit: audit_data)

      params = %{"repositories" => [%{"repository" => "hexpm", "cooldown" => "7d"}]}
      {:ok, _} = Policies.update(policy, params, audit: audit_data)

      logs =
        Hexpm.Repo.all(Hexpm.Accounts.AuditLog)
        |> Enum.filter(&(&1.action == "policy.update"))

      assert [log] = logs
      assert log.params["name"] == "pol1"
      hexpm = Enum.find(log.params["repositories"], &(&1["repository"] == "hexpm"))
      assert hexpm["cooldown"] == "7d"
      assert log.organization_id == org.id
    end
  end

  describe "delete/2" do
    test "deletes a policy", %{organization: org, audit_data: audit_data} do
      {:ok, %{policy: policy}} =
        Policies.create(org, %{"name" => "doomed", "visibility" => "public"}, audit: audit_data)

      assert {:ok, _} = Policies.delete(policy, audit: audit_data)
      assert is_nil(Policies.get(org, "doomed"))
    end

    test "writes a policy.delete audit log entry",
         %{organization: org, audit_data: audit_data} do
      {:ok, %{policy: policy}} =
        Policies.create(org, %{"name" => "doomed", "visibility" => "public"}, audit: audit_data)

      {:ok, _} = Policies.delete(policy, audit: audit_data)

      logs =
        Hexpm.Repo.all(Hexpm.Accounts.AuditLog)
        |> Enum.filter(&(&1.action == "policy.delete"))

      assert [log] = logs
      assert log.params["name"] == "doomed"
      assert log.organization_id == org.id
    end
  end

  describe "get/2 and all/1" do
    test "returns nil when missing", %{organization: org} do
      assert is_nil(Policies.get(org, "missing"))
    end

    test "returns the policy when present", %{organization: org, audit_data: audit_data} do
      {:ok, %{policy: created}} =
        Policies.create(org, %{"name" => "pol1", "visibility" => "public"}, audit: audit_data)

      assert %Policy{id: id} = Policies.get(org, "pol1")
      assert id == created.id
    end

    test "returns all policies for an org ordered by name",
         %{organization: org, audit_data: audit_data} do
      {:ok, _} =
        Policies.create(org, %{"name" => "zeta", "visibility" => "public"}, audit: audit_data)

      {:ok, _} =
        Policies.create(org, %{"name" => "alpha", "visibility" => "public"}, audit: audit_data)

      names = Policies.all(org) |> Enum.map(& &1.name)
      assert names == ["alpha", "zeta"]
    end
  end
end
