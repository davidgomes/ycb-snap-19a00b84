defmodule Mix.Tasks.ObanDoctor do
  @shortdoc "Runs all ObanDoctor checks"
  @moduledoc """
  Runs all ObanDoctor checks (workers and config).

  ## Usage

      mix oban_doctor [options]

  ## Options

    * `--format` - Output format: `text` (default) or `json`
    * `--strict` - Treat warnings as errors (exit code 1)
    * `--verbose` - Show all issues (default: shows first 3 per check type)

  ## Checks

  This task runs all available checks:

  ### Worker Checks

    * **MissingQueue** - Detects workers using queues not defined in Oban config
    * **StateGroupUsage** - Detects workers using :all state group (dangerous)
    * **UniquenessMissingStates** - Detects workers with unique config missing recommended states
    * **UniqueWithoutKeys** - Detects workers with unique on :args without explicit keys
    * **NoMaxAttempts** - Detects workers using default max_attempts (20)

  ### Config Checks

    * **InsertTriggerEnabled** - Detects instances without insert_trigger disabled
    * **MissingPruner** - Detects instances without a pruner plugin
    * **NoReindexer** - Detects instances without the Reindexer plugin
    * **SmartEngineNotConfigured** - Detects instances not using the Smart engine when Oban Pro is installed

  ## Configuration

  Checks can be configured via `.oban_doctor.exs` in your project root.
  Run `mix oban_doctor.gen.config` to generate a default config file.
  """

  use Mix.Task

  alias ObanDoctor.Config
  alias ObanDoctor.ConfigFile
  alias ObanDoctor.WorkerDiscovery
  alias ObanDoctor.ObanDiscovery
  alias ObanDoctor.Check.Worker.MissingQueue
  alias ObanDoctor.Check.Worker.UniquenessMissingStates
  alias ObanDoctor.Check.Worker.StateGroupUsage
  alias ObanDoctor.Check.Worker.UniqueWithoutKeys
  alias ObanDoctor.Check.Worker.NoMaxAttempts
  alias ObanDoctor.Check.Config.InsertTriggerEnabled
  alias ObanDoctor.Check.Config.MissingPruner
  alias ObanDoctor.Check.Config.NoReindexer
  alias ObanDoctor.Check.Config.SmartEngineNotConfigured
  alias ObanDoctor.CLI.Output

  @worker_checks [
    MissingQueue,
    StateGroupUsage,
    UniquenessMissingStates,
    UniqueWithoutKeys,
    NoMaxAttempts
  ]

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

    # Run worker checks
    IO.puts("Discovering Oban workers...")
    workers = WorkerDiscovery.discover(project_root)
    IO.puts("Found #{length(workers)} workers")

    # Filter globally excluded workers
    workers = filter_excluded_workers(workers, config)

    IO.puts("Discovering defined queues...")
    defined_queues = ObanDiscovery.discover_queues(project_root)

    IO.puts(
      "Found #{MapSet.size(defined_queues)} defined queues: #{inspect(MapSet.to_list(defined_queues))}"
    )

    # Run config checks
    IO.puts("")
    IO.puts("Discovering Oban configurations...")
    oban_configs = ObanDiscovery.discover_oban_configs(project_root)
    IO.puts("Found #{length(oban_configs)} Oban instance(s)")

    for oban_config <- oban_configs do
      instance_name = format_instance_name(oban_config.name)
      IO.puts("  - #{instance_name} (#{oban_config.app})")
    end

    IO.puts("")
    IO.puts("Running all checks...")

    worker_context = %{
      workers: workers,
      defined_queues: defined_queues,
      project_root: project_root,
      config: config
    }

    config_context = %{
      oban_configs: oban_configs,
      project_root: project_root,
      config: config
    }

    # Run all checks
    worker_issues =
      @worker_checks
      |> Enum.filter(fn check -> Config.check_enabled?(config, check.id()) end)
      |> Enum.flat_map(fn check -> run_worker_check(check, worker_context, config) end)

    config_issues =
      @config_checks
      |> Enum.filter(fn check -> Config.check_enabled?(config, check.id()) end)
      |> Enum.flat_map(fn check -> run_config_check(check, config_context, config) end)

    all_issues = worker_issues ++ config_issues

    Output.print_issues(all_issues, format: format, verbose: verbose)

    exit_code = Output.exit_code(all_issues, strict: strict)

    if exit_code != 0 do
      System.halt(exit_code)
    end
  end

  defp filter_excluded_workers(workers, config) do
    Enum.reject(workers, fn worker ->
      Config.worker_excluded?(config, worker.module) or
        Config.file_excluded?(config, worker.file)
    end)
  end

  defp run_worker_check(check, context, config) do
    # Filter workers for this specific check
    excluded_for_check = Config.excluded_workers_for_check(config, check.id())

    filtered_workers =
      Enum.reject(context.workers, fn worker ->
        worker.module in excluded_for_check
      end)

    check_context = %{context | workers: filtered_workers}
    issues = check.run(check_context)

    # Apply severity override if configured
    case Config.severity_override(config, check.id()) do
      nil -> issues
      severity -> Enum.map(issues, fn issue -> %{issue | severity: severity} end)
    end
  end

  defp run_config_check(check, context, config) do
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
