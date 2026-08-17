defmodule Mix.Tasks.ObanDoctor.CheckWorkers do
  @shortdoc "Checks Oban workers for common issues"
  @moduledoc """
  Runs checks against Oban worker definitions.

  ## Usage

      mix oban_doctor.check_workers [options]

  ## Options

    * `--format` - Output format: `text` (default) or `json`
    * `--strict` - Treat warnings as errors (exit code 1)

  ## Checks

  This task runs the following checks:

    * **MissingQueue** - Detects workers using queues not defined in Oban config
    * **StateGroupUsage** - Detects workers using :all state group (dangerous)
    * **UniquenessMissingStates** - Detects workers with unique config missing recommended states
    * **UniqueWithoutKeys** - Detects workers with unique on :args without explicit keys
    * **NoMaxAttempts** - Detects workers using default max_attempts (20)

  ## Configuration

  Checks can be configured via `.oban_doctor.exs` in your project root.
  Run `mix oban_doctor.gen.config` to generate a default config file.
  """

  use Mix.Task

  alias ObanDoctor.Config
  alias ObanDoctor.ConfigFile
  alias ObanDoctor.WorkerDiscovery
  alias ObanDoctor.ObanConfigDiscovery
  alias ObanDoctor.Check.Worker.MissingQueue
  alias ObanDoctor.Check.Worker.UniquenessMissingStates
  alias ObanDoctor.Check.Worker.StateGroupUsage
  alias ObanDoctor.Check.Worker.UniqueWithoutKeys
  alias ObanDoctor.Check.Worker.NoMaxAttempts
  alias ObanDoctor.CLI.Output

  @worker_checks [
    MissingQueue,
    StateGroupUsage,
    UniquenessMissingStates,
    UniqueWithoutKeys,
    NoMaxAttempts
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [format: :string, strict: :boolean],
        aliases: [f: :format, s: :strict]
      )

    format = parse_format(Keyword.get(opts, :format, "text"))
    strict = Keyword.get(opts, :strict, false)

    project_root = File.cwd!()

    # Load configuration
    config = ConfigFile.load!(project_root)

    IO.puts("Discovering Oban workers...")
    workers = WorkerDiscovery.discover(project_root)
    IO.puts("Found #{length(workers)} workers")

    # Filter excluded workers
    workers = filter_excluded_workers(workers, config)

    IO.puts("Discovering defined queues...")
    defined_queues = ObanConfigDiscovery.discover_queues(project_root)

    IO.puts(
      "Found #{MapSet.size(defined_queues)} defined queues: #{inspect(MapSet.to_list(defined_queues))}"
    )

    IO.puts("")
    IO.puts("Running worker checks...")

    context = %{
      workers: workers,
      defined_queues: defined_queues,
      project_root: project_root,
      config: config
    }

    # Filter enabled checks and run them
    issues =
      @worker_checks
      |> Enum.filter(fn check -> Config.check_enabled?(config, check.id()) end)
      |> Enum.flat_map(fn check -> run_check(check, context, config) end)

    Output.print_issues(issues, format: format)

    exit_code = Output.exit_code(issues, strict: strict)

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

  defp run_check(check, context, config) do
    issues = check.run(context)

    # Apply severity override if configured
    case Config.severity_override(config, check.id()) do
      nil -> issues
      severity -> Enum.map(issues, fn issue -> %{issue | severity: severity} end)
    end
  end

  defp parse_format("json"), do: :json
  defp parse_format(_), do: :text
end
