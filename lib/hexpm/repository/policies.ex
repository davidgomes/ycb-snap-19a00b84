defmodule Hexpm.Repository.Policies do
  use Hexpm.Context
  import Ecto.Query

  alias Hexpm.Repository.Policy

  def all(organization) do
    Policy
    |> where([p], p.organization_id == ^organization.id)
    |> order_by([p], asc: p.name)
    |> Repo.all()
  end

  def get(organization, name) do
    Policy
    |> where([p], p.organization_id == ^organization.id and p.name == ^name)
    |> Repo.one()
  end

  def change(organization, %Policy{} = policy, params \\ %{}) do
    params = put_repositories(params, organization.name, policy.repositories)
    Policy.changeset(policy, params)
  end

  def create(organization, params, audit: audit_data) do
    params = put_repositories(params, organization.name, [])

    changeset =
      %Policy{organization_id: organization.id}
      |> Policy.changeset(params)

    Multi.new()
    |> Multi.insert(:policy, changeset)
    |> audit(audit_data, "policy.create", fn %{policy: policy} -> policy end)
    |> Repo.transaction()
    |> tap(&maybe_rebuild/1)
  end

  def update(%Policy{} = policy, params, audit: audit_data) do
    policy = Repo.preload(policy, :organization)
    params = put_repositories(params, policy.organization.name, policy.repositories)
    changeset = Policy.changeset(policy, params)

    Multi.new()
    |> Multi.update(:policy, changeset)
    |> audit(audit_data, "policy.update", fn %{policy: updated} -> updated end)
    |> Repo.transaction()
    |> tap(&maybe_rebuild/1)
  end

  # Every policy carries a tab for `hexpm` and one for the organization's own
  # repository. The org tab is only published for private policies (see
  # `PolicyBuilder`) but is always stored so toggling visibility keeps its
  # rules. The source is the submitted tabs, or the policy's existing tabs when
  # the caller did not resubmit them; tabs are matched by repository name so
  # their id and rules survive.
  defp put_repositories(params, org_name, existing) do
    source =
      case params["repositories"] do
        nil -> Enum.map(existing, &tab_to_params/1)
        repositories -> submitted_repositories(repositories)
      end

    by_repository = Map.new(source, &{&1["repository"], &1})

    repositories =
      Enum.map(["hexpm", org_name], fn repository ->
        Map.get(by_repository, repository, %{"repository" => repository})
      end)

    Map.put(params, "repositories", repositories)
  end

  defp submitted_repositories(repositories) do
    repositories
    |> params_list()
    |> Enum.map(&put_submitted_overrides/1)
  end

  # A submitted tab lists every override it keeps. A form with no rows left
  # posts no `overrides` key, which `cast_embed` would read as unchanged, and
  # an entry without a package is a leftover id from a removed row.
  defp put_submitted_overrides(tab) when is_map(tab) do
    overrides =
      tab
      |> Map.get("overrides")
      |> params_list()
      |> Enum.filter(&(is_map(&1) and Map.has_key?(&1, "package")))

    Map.put(tab, "overrides", overrides)
  end

  defp put_submitted_overrides(tab), do: tab

  defp params_list(nil), do: []
  defp params_list(list) when is_list(list), do: list

  defp params_list(map) when is_map(map) do
    map
    |> Enum.sort_by(fn {key, _value} -> index_key(key) end)
    |> Enum.map(fn {_key, value} -> value end)
  end

  defp params_list(_other), do: []

  defp index_key(key) when is_binary(key) do
    case Integer.parse(key) do
      {int, ""} -> {0, int, key}
      _ -> {1, 0, key}
    end
  end

  defp index_key(key), do: {1, 0, key}

  defp tab_to_params(repository_policy) do
    %{
      "id" => repository_policy.id,
      "repository" => repository_policy.repository,
      "cooldown" => repository_policy.cooldown,
      "advisory_min_severity" => repository_policy.advisory_min_severity,
      "retirement_reasons" => repository_policy.retirement_reasons,
      "overrides" =>
        Enum.map(repository_policy.overrides, fn override ->
          %{
            "id" => override.id,
            "action" => override.action,
            "package" => override.package,
            "requirement" => override.requirement
          }
        end)
    }
  end

  def delete(%Policy{} = policy, audit: audit_data) do
    Multi.new()
    |> Multi.delete(:policy, policy)
    |> audit(audit_data, "policy.delete", policy)
    |> Repo.transaction()
    |> tap(&maybe_delete/1)
  end

  defp maybe_rebuild({:ok, %{policy: policy}}), do: Hexpm.Repository.PolicyBuilder.rebuild(policy)
  defp maybe_rebuild(_), do: :ok

  defp maybe_delete({:ok, %{policy: policy}}), do: Hexpm.Repository.PolicyBuilder.delete(policy)
  defp maybe_delete(_), do: :ok
end
