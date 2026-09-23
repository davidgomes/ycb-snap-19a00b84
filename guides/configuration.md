# Configuration

ObanDoctor can be configured via a `.oban_doctor.exs` file in your project root. This file allows you to enable/disable checks, override severities, and exclude specific workers or files from analysis.

## Generating a Config File

Generate a config file with all available checks:

```bash
mix oban_doctor.gen.config
```

This creates `.oban_doctor.exs` with all checks listed and their default settings.

## Config Keys

### `:checks`

A keyword list of check configurations. Each check can be configured with:

- `enabled` - Enable or disable the check (default: `true`)
- `severity` - Override the default severity (`:error`, `:warning`, or `:info`)

```elixir
[
  checks: [
    missing_queue: [enabled: true],
    state_group_usage: [enabled: true, severity: :error],
    unique_without_keys: [enabled: false]
  ]
]
```

Checks not listed in the config are enabled by default with their default severity.

### `:excluded_workers`

A list of worker modules to exclude from all checks. Useful for legacy workers or workers that intentionally deviate from best practices.

```elixir
[
  excluded_workers: [
    MyApp.Workers.LegacyWorker,
    MyApp.Workers.SpecialCaseWorker
  ]
]
```

### `:excluded_files`

A list of file path patterns to exclude from analysis. Any file whose path contains one of these patterns will be skipped.

```elixir
[
  excluded_files: [
    "test/support/",
    "priv/repo/seeds/"
  ]
]
```

## Complete Example

```elixir
# .oban_doctor.exs

[
  checks: [
    # Worker checks
    missing_queue: [enabled: true],
    state_group_usage: [enabled: true],
    uniqueness_missing_states: [enabled: true, severity: :info],
    unique_without_keys: [enabled: false],
    no_max_attempts: [enabled: true],

    # Config checks
    insert_trigger_enabled: [enabled: true],
    missing_pruner: [enabled: true],
    no_reindexer: [enabled: true, severity: :info],
    smart_engine_not_configured: [enabled: true]
  ],

  excluded_workers: [
    MyApp.Workers.LegacyWorker
  ],

  excluded_files: [
    "test/support/"
  ]
]
```

## Available Checks

### Worker Checks

| ID | Default Severity | Description |
|----|------------------|-------------|
| `missing_queue` | `:error` | Workers using undefined queues |
| `state_group_usage` | `:error` | Workers using dangerous `:all` state group |
| `uniqueness_missing_states` | `:warning` | Unique configs missing recommended states |
| `unique_without_keys` | `:warning` | Unique on `:args` without explicit `keys` |
| `no_max_attempts` | `:info` | Workers using default `max_attempts` of 20 |

### Config Checks

| ID | Default Severity | Description |
|----|------------------|-------------|
| `insert_trigger_enabled` | `:warning` | Oban instances without `insert_trigger: false` |
| `missing_pruner` | `:warning` | Oban instances without a pruner plugin |
| `no_reindexer` | `:warning` | Oban instances without the Reindexer plugin |
| `smart_engine_not_configured` | `:warning` | Oban instances not using the Smart engine when Oban Pro is installed |

## Severity Levels

- `:error` - Serious issues that should be fixed. Causes non-zero exit code.
- `:warning` - Potential problems worth reviewing. Causes non-zero exit code with `--strict`.
- `:info` - Informational suggestions. Never causes non-zero exit code.

## Using with CI

For CI pipelines, use `--strict` to treat warnings as errors:

```bash
mix oban_doctor.check_workers --strict
mix oban_doctor.check_config --strict
```

For JSON output (useful for custom reporting tools):

```bash
mix oban_doctor.check_workers --format=json
```
