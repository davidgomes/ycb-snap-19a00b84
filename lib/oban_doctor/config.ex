defmodule ObanDoctor.Config do
  @moduledoc """
  Configuration struct for ObanDoctor.

  Configuration is provided via `.oban_doctor.exs` in the project root.
  Generate a default config file with `mix oban_doctor.gen.config`.

  ## Configuration Options

  ### Per-check options

  Each check can be configured with:

    * `:enabled` - Enable or disable the check (default: `true`)
    * `:severity` - Override the default severity (`:error`, `:warning`, or `:info`)
    * `:excluded_workers` - List of worker modules to exclude (worker checks only)
    * `:excluded_instances` - List of Oban instance modules to exclude (config checks only)

  ### Global options

    * `:excluded_workers` - Exclude workers from ALL worker checks
    * `:excluded_files` - Exclude files matching patterns from ALL checks

  ## Example

      [
        checks: [
          # Disable a check
          unique_without_keys: [enabled: false],

          # Override severity
          no_max_attempts: [severity: :info],

          # Exclude specific workers from this check
          missing_queue: [
            excluded_workers: [MyApp.Workers.LegacyWorker]
          ],

          # Exclude specific Oban instances from this check
          missing_pruner: [
            excluded_instances: [MyApp.SecondaryOban]
          ]
        ],

        # Global exclusions
        excluded_workers: [MyApp.Workers.DeprecatedWorker],
        excluded_files: ["test/support/"]
      ]
  """

  @type check_config :: %{
          enabled: boolean(),
          severity: ObanDoctor.Issue.severity() | nil,
          excluded_workers: [module()],
          excluded_instances: [module()]
        }

  @type t :: %__MODULE__{
          checks: %{atom() => check_config()},
          excluded_workers: [module()],
          excluded_files: [String.t()]
        }

  defstruct checks: %{},
            excluded_workers: [],
            excluded_files: []

  @doc """
  Creates a new config with defaults.
  """
  def new(attrs \\ []) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Returns whether a check is enabled.
  """
  def check_enabled?(%__MODULE__{checks: checks}, check_id) do
    case Map.get(checks, check_id) do
      %{enabled: enabled} -> enabled
      nil -> true
    end
  end

  @doc """
  Returns the severity override for a check, or nil if not overridden.
  """
  def severity_override(%__MODULE__{checks: checks}, check_id) do
    case Map.get(checks, check_id) do
      %{severity: severity} when not is_nil(severity) -> severity
      _ -> nil
    end
  end

  @doc """
  Returns whether a worker is excluded from checks.
  """
  def worker_excluded?(%__MODULE__{excluded_workers: excluded}, worker_module) do
    worker_module in excluded
  end

  @doc """
  Returns whether a file is excluded from checks.
  """
  def file_excluded?(%__MODULE__{excluded_files: excluded}, file_path) do
    Enum.any?(excluded, fn pattern ->
      String.contains?(file_path, pattern)
    end)
  end

  @doc """
  Returns workers excluded for a specific check.
  """
  def excluded_workers_for_check(%__MODULE__{checks: checks}, check_id) do
    case Map.get(checks, check_id) do
      %{excluded_workers: workers} when is_list(workers) -> workers
      _ -> []
    end
  end

  @doc """
  Returns instances excluded for a specific check.
  """
  def excluded_instances_for_check(%__MODULE__{checks: checks}, check_id) do
    case Map.get(checks, check_id) do
      %{excluded_instances: instances} when is_list(instances) -> instances
      _ -> []
    end
  end

  @doc """
  Merges config from a keyword list (from .oban_doctor.exs).
  """
  def from_keyword(keyword) when is_list(keyword) do
    checks =
      keyword
      |> Keyword.get(:checks, [])
      |> Enum.map(fn {check_id, opts} ->
        {check_id,
         %{
           enabled: Keyword.get(opts, :enabled, true),
           severity: Keyword.get(opts, :severity),
           excluded_workers: Keyword.get(opts, :excluded_workers, []),
           excluded_instances: Keyword.get(opts, :excluded_instances, [])
         }}
      end)
      |> Map.new()

    excluded_workers =
      keyword
      |> Keyword.get(:excluded_workers, [])

    excluded_files =
      keyword
      |> Keyword.get(:excluded_files, [])

    %__MODULE__{
      checks: checks,
      excluded_workers: excluded_workers,
      excluded_files: excluded_files
    }
  end
end
