defmodule ObanDoctor.Config do
  @moduledoc """
  Configuration struct for ObanDoctor.

  Configuration can be provided via `.oban_doctor.exs` in the project root.
  """

  @type check_config :: %{
          enabled: boolean(),
          severity: ObanDoctor.Issue.severity() | nil
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
           severity: Keyword.get(opts, :severity)
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
