defmodule Mix.Tasks.ObanDoctor.Gen.Config do
  @shortdoc "Generates a .oban_doctor.exs configuration file"
  @moduledoc """
  Generates a default `.oban_doctor.exs` configuration file.

  ## Usage

      mix oban_doctor.gen.config

  This will create a `.oban_doctor.exs` file in your project root with
  default configuration for all available checks.

  If a config file already exists, you will be prompted to overwrite it.
  """

  use Mix.Task

  alias ObanDoctor.ConfigFile
  alias ObanDoctor.Check.Worker.MissingQueue
  alias ObanDoctor.Check.Worker.UniquenessMissingStates
  alias ObanDoctor.Check.Worker.StateGroupUsage
  alias ObanDoctor.Check.Worker.UniqueWithoutKeys
  alias ObanDoctor.Check.Worker.NoMaxAttempts
  alias ObanDoctor.Check.Config.InsertTriggerEnabled
  alias ObanDoctor.Check.Config.MissingPruner
  alias ObanDoctor.Check.Config.NoReindexer

  @all_checks [
    # Worker checks
    MissingQueue,
    StateGroupUsage,
    UniquenessMissingStates,
    UniqueWithoutKeys,
    NoMaxAttempts,
    # Config checks
    InsertTriggerEnabled,
    MissingPruner,
    NoReindexer
  ]

  @impl Mix.Task
  def run(_args) do
    project_root = File.cwd!()
    config_path = ConfigFile.config_path(project_root)

    if File.exists?(config_path) do
      if Mix.shell().yes?("Config file already exists. Overwrite?") do
        write_config(config_path)
      else
        Mix.shell().info("Aborted.")
      end
    else
      write_config(config_path)
    end
  end

  defp write_config(path) do
    content = ConfigFile.default_config_content(@all_checks)
    File.write!(path, content)
    Mix.shell().info("Created #{path}")
  end
end
