defmodule ObanDoctor do
  @moduledoc """
  ObanDoctor - Static analysis tool for Oban workers and configuration.

  ObanDoctor helps catch common Oban misconfigurations and worker bugs at CI time
  through static analysis of your codebase.

  ## Usage

  Run checks via mix tasks:

      # Check workers for issues
      mix oban_doctor.check_workers

      # Check Oban configuration (coming soon)
      mix oban_doctor.check_config

      # Run all checks (coming soon)
      mix oban_doctor

  ## Checks

  ### Worker Checks

    * `MissingQueue` - Workers using queues not defined in Oban config

  More checks coming soon.
  """

  alias ObanDoctor.WorkerDiscovery
  alias ObanDoctor.ObanConfigDiscovery

  @doc """
  Discovers all Oban workers in the given project root.
  """
  def discover_workers(root_path \\ File.cwd!()) do
    WorkerDiscovery.discover(root_path)
  end

  @doc """
  Discovers all defined Oban queues from config files.
  """
  def discover_queues(root_path \\ File.cwd!()) do
    ObanConfigDiscovery.discover_queues(root_path)
  end
end
