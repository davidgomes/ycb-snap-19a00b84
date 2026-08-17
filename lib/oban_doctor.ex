defmodule ObanDoctor do
  @moduledoc """
  ObanDoctor - Static analysis tool for Oban workers and configuration.

  ObanDoctor helps catch common Oban misconfigurations and worker bugs at CI time
  through static analysis of your codebase.

  ## Usage

  Run checks via mix tasks:

      # Run all checks
      mix oban_doctor

      # Or run specific check types
      mix oban_doctor.check_workers  # Worker checks only
      mix oban_doctor.check_config   # Config checks only

  ## Options

    * `--format` - Output format: `text` (default) or `json`
    * `--strict` - Treat warnings as errors (exit code 1)
    * `--verbose` - Show all issues (default: shows first 3 per check type)

  ## Configuration

  Generate a config file to customize checks:

      mix oban_doctor.gen.config

  See `ObanDoctor.Config` for configuration options.
  """
end
