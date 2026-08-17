<picture>
  <img src="./priv/static/logo.png" alt="Oban Doctor logo" />
</picture>

# ObanDoctor

[![Hex.pm](https://img.shields.io/hexpm/v/oban_doctor.svg)](https://hex.pm/packages/oban_doctor)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-blue.svg)](https://hexdocs.pm/oban_doctor/readme.html)
[![Coverage Status](https://coveralls.io/repos/github/tomasz-tomczyk/oban_doctor/badge.svg?branch=main)](https://coveralls.io/github/tomasz-tomczyk/oban_doctor?branch=main)

Static analysis and runtime monitoring for Oban. Catches misconfigurations at CI time and provides runtime queue metrics for capacity planning. Based on lessons learnt over many years of happily using Oban.

## Installation

Add `oban_doctor` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:oban_doctor, "~> 0.2"}
  ]
end
```

**For static analysis only** (checks without runtime plugins):

```elixir
{:oban_doctor, "~> 0.2", only: [:dev, :test], runtime: false}
```

## Usage

Run all checks:

```bash
mix oban_doctor
```

Or run specific check types:

```bash
mix oban_doctor.check_workers  # Worker checks only
mix oban_doctor.check_config   # Config checks only
```

Options:

- `--format=json` - Output as JSON (for CI integration)
- `--strict` - Treat warnings as errors (exit code 1)
- `--verbose` - Show detailed output

## Checks

### Worker Checks

| Check                                                                                                          | Description                                                         |
| -------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| [MissingQueue](https://hexdocs.pm/oban_doctor/ObanDoctor.Check.Worker.MissingQueue.html)                       | Detects workers using queues not defined in Oban configuration      |
| [StateGroupUsage](https://hexdocs.pm/oban_doctor/ObanDoctor.Check.Worker.StateGroupUsage.html)                 | Detects workers using the dangerous `:all` state group              |
| [UniquenessMissingStates](https://hexdocs.pm/oban_doctor/ObanDoctor.Check.Worker.UniquenessMissingStates.html) | Detects unique configs missing recommended states like `:retryable` |
| [UniqueWithoutKeys](https://hexdocs.pm/oban_doctor/ObanDoctor.Check.Worker.UniqueWithoutKeys.html)             | Detects unique constraints on `:args` without explicit `keys`       |
| [NoMaxAttempts](https://hexdocs.pm/oban_doctor/ObanDoctor.Check.Worker.NoMaxAttempts.html)                     | Detects workers using the default `max_attempts` of 20              |

### Config Checks

| Check                                                                                                    | Description                                                                   |
| -------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| [InsertTriggerEnabled](https://hexdocs.pm/oban_doctor/ObanDoctor.Check.Config.InsertTriggerEnabled.html) | Detects Oban instances without `insert_trigger: false` (performance overhead) |
| [MissingPruner](https://hexdocs.pm/oban_doctor/ObanDoctor.Check.Config.MissingPruner.html)               | Detects Oban instances without a pruner plugin (jobs accumulate indefinitely) |
| [NoReindexer](https://hexdocs.pm/oban_doctor/ObanDoctor.Check.Config.NoReindexer.html)                   | Detects Oban instances without the Reindexer plugin (index bloat)             |
| [SmartEngineNotConfigured](https://hexdocs.pm/oban_doctor/ObanDoctor.Check.Config.SmartEngineNotConfigured.html) | Detects Oban instances without SmartEngine configured when Oban Pro is installed |

## Runtime Plugins

ObanDoctor provides runtime plugins for monitoring queue health and capacity. See the [Plugins Guide](https://hexdocs.pm/oban_doctor/plugins.html) for usage details.

| Plugin                                                                              | Description                                          |
| ----------------------------------------------------------------------------------- | ---------------------------------------------------- |
| [QueueMetrics](https://hexdocs.pm/oban_doctor/ObanDoctor.Plugins.QueueMetrics.html) | Live queue metrics including utilization percentages |
| [TableHealth](https://hexdocs.pm/oban_doctor/ObanDoctor.Plugins.TableHealth.html)   | Table size, bloat, and vacuum monitoring with alerts |
| [IndexHealth](https://hexdocs.pm/oban_doctor/ObanDoctor.Plugins.IndexHealth.html)   | Index size, usage, and health monitoring with alerts |

## Configuration

Create a `.oban_doctor.exs` file in your project root to customize behavior:

```bash
mix oban_doctor.gen.config
```

Example:

```elixir
[
  checks: [
    # Disable a check entirely
    unique_without_keys: [enabled: false],

    # Override severity
    no_max_attempts: [severity: :info],

    # Exclude specific workers from a worker check
    missing_queue: [
      excluded_workers: [MyApp.Workers.LegacyWorker]
    ],

    # Exclude specific Oban instances from a config check
    missing_pruner: [
      excluded_instances: [MyApp.SecondaryOban]
    ]
  ],

  # Exclude workers from ALL worker checks
  excluded_workers: [MyApp.Workers.DeprecatedWorker],

  # Exclude files from ALL checks
  excluded_files: ["test/support/"]
]
```

See the [Configuration Guide](https://hexdocs.pm/oban_doctor/configuration.html) for full documentation.

## CI Integration

Add to your CI pipeline:

```bash
mix oban_doctor --strict
```

For JSON output (useful for custom reporting):

```bash
mix oban_doctor --format=json
```

Exit codes:

- `0` - No errors (warnings are allowed unless `--strict`)
- `1` - Errors found (or warnings with `--strict`)

## License

Apache 2.0
