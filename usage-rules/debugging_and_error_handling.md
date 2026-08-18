<!--
SPDX-FileCopyrightText: 2020 Zach Daniel

SPDX-License-Identifier: MIT
-->

# Debugging and Error Handling

AshOban provides options for debugging and handling errors:

```elixir
trigger :process do
  action :process
  # Enable detailed debug logging for this trigger
  debug? true

  # Configure error handling
  log_errors? true
  log_final_error? true

  # Define an action to call after the last attempt has failed
  on_error :mark_failed
end
```

You can also enable global debug logging:

```elixir
config :ash_oban, :debug_all_triggers?, true
```

## Snoozing and Cancelling Jobs

Actions run by a trigger or scheduled action can snooze or cancel their Oban job by returning
(or raising) the errors built by `AshOban.snooze/1` and `AshOban.cancel/1`:

```elixir
update :process do
  require_atomic? false

  change fn changeset, _context ->
    if rate_limited?() do
      # run again in 60 seconds, without using up an attempt
      Ash.Changeset.add_error(changeset, AshOban.snooze(60))
    else
      changeset
    end
  end
end

action :process do
  run fn _input, _context ->
    # don't retry, no matter how many attempts are left
    {:error, AshOban.cancel("nothing to do")}
  end
end
```

Snoozing and cancelling take precedence over the `on_error` action, and are not logged as errors.