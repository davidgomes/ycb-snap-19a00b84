defmodule Mix.Tasks.ObanDoctor.CheckConfig do
  @shortdoc "Checks Oban configuration for common issues"
  @moduledoc """
  Runs checks against Oban configuration.

  ## Usage

      mix oban_doctor.check_config [options]

  ## Options

    * `--format` - Output format: `text` (default) or `json`
    * `--strict` - Treat warnings as errors (exit code 1)
    * `--verbose` - Show all issues (default: shows first 3 per check type)

  ## Checks

  This task runs the following checks:

    * **InsertTriggerEnabled** - Detects instances without insert_trigger disabled
    * **MissingPruner** - Detects instances without a pruner plugin
    * **NoReindexer** - Detects instances without the Reindexer plugin
    * **SmartEngineNotConfigured** - Detects instances without SmartEngine when Oban Pro is installed

  ## Configuration

  Checks can be configured via `.oban_doctor.exs` in your project root.
  Run `mix oban_doctor.gen.config` to generate a default config file.
  """

  use Mix.Task

  alias ObanDoctor.Config
  alias ObanDoctor.ConfigFile
  alias ObanDoctor.ObanDiscovery
  alias ObanDoctor.Check.Config.InsertTriggerEnabled
  alias ObanDoctor.Check.Config.MissingPruner
  alias ObanDoctor.Check.Config.NoReindexer
  alias ObanDoctor.Check.Config.SmartEngineNotConfigured
  alias ObanDoctor.CLI.Output

  @config_checks [
    InsertTriggerEnabled,
    MissingPruner,
    NoReindexer,
    SmartEngineNotConfigured
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [format: :string, strict: :boolean, verbose: :boolean],
        aliases: [f: :format, s: :strict, v: :verbose]
      )

    format = parse_format(Keyword.get(opts, :format, "text"))
    strict = Keyword.get(opts, :strict, false)
    verbose = Keyword.get(opts, :verbose, false)

    project_root = File.cwd!()

    # Load configuration
    config = ConfigFile.load!(project_root)

    IO.puts("Discovering Oban configurations...")
    oban_configs = ObanDiscovery.discover_oban_configs(project_root)
    IO.puts("Found #{length(oban_configs)} Oban instance(s)")

    for oban_config <- oban_configs do
      instance_name = format_instance_name(oban_config.name)
      IO.puts("  - #{instance_name} (#{oban_config.app})")
    end

    IO.puts("")
    IO.puts("Running config checks...")

    context = %{
      oban_configs: oban_configs,
      project_root: project_root,
      config: config
    }

    # Filter enabled checks and run them
    issues =
      @config_checks
      |> Enum.filter(fn check -> Config.check_enabled?(config, check.id()) end)
      |> Enum.flat_map(fn check -> run_check(check, context, config) end)

    Output.print_issues(issues, format: format, verbose: verbose)

    exit_code = Output.exit_code(issues, strict: strict)

    if exit_code != 0 do
      System.halt(exit_code)
    end
  end

  defp run_check(check, context, config) do
    # Filter instances for this specific check
    excluded_for_check = Config.excluded_instances_for_check(config, check.id())

    filtered_configs =
      Enum.reject(context.oban_configs, fn oban_config ->
        oban_config.name in excluded_for_check
      end)

    check_context = %{context | oban_configs: filtered_configs}
    issues = check.run(check_context)

    # Apply severity override if configured
    case Config.severity_override(config, check.id()) do
      nil -> issues
      severity -> Enum.map(issues, fn issue -> %{issue | severity: severity} end)
    end
  end

  defp parse_format("json"), do: :json
  defp parse_format(_), do: :text

  defp format_instance_name(Oban), do: "Oban"
  defp format_instance_name(name), do: inspect(name)
end
