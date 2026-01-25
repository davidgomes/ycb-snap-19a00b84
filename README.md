# ObanDoctor

Static analysis tool for Oban workers and configuration. Catches misconfigurations and worker bugs at CI time through AST parsing—no runtime dependency on Oban required.

## Installation

Add `oban_doctor` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:oban_doctor, "~> 0.1.0", only: [:dev, :test], runtime: false}
  ]
end
```

## Usage

Run all worker checks:

```bash
mix oban_doctor.check_workers
```

Options:
- `--format=json` - Output as JSON (for CI integration)
- `--strict` - Treat warnings as errors (exit code 1)

Generate a configuration file:

```bash
mix oban_doctor.gen.config
```

## Checks

### Worker Checks

#### MissingQueue (error)

Detects workers using queues that are not defined in your Oban configuration. See [Oban queue configuration](https://hexdocs.pm/oban/Oban.html#module-configuring-queues).

```elixir
# Bad - :misc queue is not defined
use Oban.Worker, queue: :misc

# Good - use a queue defined in your config
use Oban.Worker, queue: :default
```

#### StateGroupUsage (error)

Detects workers using the `:all` state group in unique configuration. Oban provides named state groups:

- `:successful` (default) - excludes cancelled/discarded, safe for most cases
- `:incomplete` - only unfinished jobs, good for preventing concurrent execution
- `:scheduled` - only scheduled jobs, useful for debouncing
- `:all` - includes cancelled/discarded (DANGEROUS - jobs can never be re-enqueued)

See [Oban unique jobs](https://hexdocs.pm/oban/unique_jobs.html).

```elixir
# Bad - prevents re-enqueueing forever
use Oban.Worker, unique: [fields: [:args], states: :all]

# Good - use a named group
use Oban.Worker, unique: [fields: [:args], states: :incomplete]

# Good - explicit states
use Oban.Worker, unique: [fields: [:args], states: [:available, :scheduled, :executing, :retryable]]
```

#### UniquenessMissingStates (warning)

Detects workers with explicit state lists that are missing recommended states. **Missing `:retryable` is a common issue** - when a job fails and enters retryable state (with backoff), a new job with the same unique key can be enqueued, causing duplicates during deployments or scaling.

This check does NOT flag named groups (`:incomplete`, `:scheduled`, `:successful`) as these are valid Oban patterns. See [Oban unique jobs](https://hexdocs.pm/oban/unique_jobs.html).

```elixir
# Bad - missing :retryable causes duplicates during retries
use Oban.Worker, unique: [fields: [:args], states: [:available, :scheduled, :executing]]

# Good - includes all non-final states
use Oban.Worker, unique: [fields: [:args], states: [:available, :scheduled, :executing, :retryable]]

# Better - use a named group instead
use Oban.Worker, unique: [fields: [:args], states: :incomplete]
```

#### UniqueWithoutKeys (info)

Detects workers with unique constraint on `:args` but no explicit `keys` option. Without `keys`, all args fields are used for uniqueness which may not be intentional. See [Oban unique jobs](https://hexdocs.pm/oban/unique_jobs.html).

```elixir
# Potentially problematic - uses ALL args fields
use Oban.Worker, unique: [fields: [:args]]

# Better - explicit about which args matter
use Oban.Worker, unique: [fields: [:args], keys: [:user_id, :action]]
```

#### NoMaxAttempts (info)

Detects workers using the default `max_attempts` of 20. This is often too high and can waste resources on operations unlikely to succeed. See [Oban.Worker options](https://hexdocs.pm/oban/Oban.Worker.html#module-defining-workers).

```elixir
# Using default (20 attempts)
use Oban.Worker, queue: :default

# Explicit reasonable limit
use Oban.Worker, queue: :default, max_attempts: 3
```

## Configuration

Create a `.oban_doctor.exs` file in your project root to customize behavior:

```elixir
[
  checks: [
    missing_queue: [enabled: true],
    state_group_usage: [enabled: true],
    uniqueness_missing_states: [enabled: true, severity: :info],
    unique_without_keys: [enabled: false],
    no_max_attempts: [enabled: true]
  ],

  # Exclude specific workers from all checks
  excluded_workers: [
    MyApp.Workers.LegacyWorker
  ],

  # Exclude files matching these patterns
  excluded_files: [
    "test/support/"
  ]
]
```

### Configuration Options

- `enabled` - Enable or disable a check (default: `true`)
- `severity` - Override the default severity (`:error`, `:warning`, or `:info`)
- `excluded_workers` - List of worker modules to skip
- `excluded_files` - List of file path patterns to skip

## CI Integration

Add to your CI pipeline:

```bash
mix oban_doctor.check_workers --strict
```

For JSON output (useful for custom reporting):

```bash
mix oban_doctor.check_workers --format=json
```

Exit codes:
- `0` - No errors (warnings are allowed unless `--strict`)
- `1` - Errors found (or warnings with `--strict`)

## License

MIT
