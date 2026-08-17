defmodule ObanDoctor.Check.Config.Helpers do
  @moduledoc false

  @doc """
  Finds configs missing a required plugin, grouping by repo.

  Database-level plugins (like Pruner and Reindexer) only need to be configured
  once per repo. This function:

  1. Groups configs by repo
  2. For each repo, checks if ANY instance has the required plugin
  3. Returns one issue per repo (not per instance) when missing
  4. Handles nil repo configs individually (can't determine if they share a repo)

  ## Parameters

  - `oban_configs` - List of Oban config maps
  - `has_plugin?` - Predicate function that returns true if config has the plugin
  - `build_issue` - Function that builds an issue from a config

  ## Example

      find_configs_missing_plugin(
        oban_configs,
        &has_pruner?/1,
        &build_issue/1
      )
  """
  def find_configs_missing_plugin(oban_configs, has_plugin?, build_issue) do
    {with_repo, without_repo} = Enum.split_with(oban_configs, &(&1.repo != nil))

    repos_with_plugin =
      with_repo
      |> Enum.filter(has_plugin?)
      |> Enum.map(& &1.repo)
      |> MapSet.new()

    # For configs with a repo, only flag if no instance for that repo has the plugin
    repo_issues =
      with_repo
      |> Enum.filter(fn config -> config.repo not in repos_with_plugin end)
      |> Enum.uniq_by(& &1.repo)
      |> Enum.map(build_issue)

    # For configs without a repo, check individually (legacy behavior)
    missing_plugin? = fn config -> not has_plugin?.(config) end

    no_repo_issues =
      without_repo
      |> Enum.filter(missing_plugin?)
      |> Enum.map(build_issue)

    repo_issues ++ no_repo_issues
  end

  @doc """
  Formats an Oban instance name for display.
  """
  def format_instance_name(Oban), do: "Oban"
  def format_instance_name(name), do: inspect(name)
end
