# ObanEvents

A lightweight, persistent event bus for Elixir applications built on top of [Oban](https://github.com/sorentwo/oban).

## Features

- 🔒 **Persistent** - Events survive application restarts (stored in Oban's database)
- 🔄 **Reliable** - Automatic retries on failure via Oban
- ⚡ **Async** - Non-blocking execution of handlers
- 🔗 **Transactional** - Works within database transactions for atomicity
- 📊 **Observable** - Track event processing via Oban Web UI
- ✅ **Type-safe** - Compile-time validation of events
- 🎯 **Decoupled** - Event emitters don't know about handlers
- 🏷️ **Traceable** - Every event carries an ID, timestamp, causation/correlation IDs, and custom metadata
- 🧪 **Testable** - Built-in helpers for asserting emitted events and exercising handlers

## Installation

Add `oban_events` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:oban_events, "~> 0.1.0"},
    {:oban, "~> 2.0"},
    {:postgrex, ">= 0.0.0"}  # Required by Oban
  ]
end
```

## Quick Start

### 1. Define Your Event Bus

Create a module that uses `ObanEvents` and define your events and handlers:

```elixir
defmodule MyApp.Events do
  use ObanEvents,
    oban: MyApp.Oban,
    queue: :myapp_events,
    max_attempts: 3,
    priority: 2

  @event_handlers %{
    user_created: [MyApp.EmailHandler, MyApp.AnalyticsHandler],
    user_updated: [MyApp.CacheHandler],
    order_placed: [MyApp.NotificationHandler]
  }
end
```

### 2. Create Event Handlers

Implement the `ObanEvents.Handler` behaviour:

Handlers receive the event name and an `ObanEvents.Event` struct:

```elixir
defmodule MyApp.EmailHandler do
  use ObanEvents.Handler

  alias ObanEvents.Event

  require Logger

  @impl true
  def handle_event(:user_created, %Event{data: data}) do
    %{"user_id" => user_id, "email" => email} = data

    Logger.info("Sending welcome email to #{email}")
    MyApp.Mailer.send_welcome_email(email)

    :ok
  end

  @impl true
  def handle_event(_event_name, _event), do: :ok
end
```

### 3. Emit Events

Emit events from your application code, preferably within transactions:

```elixir
defmodule MyApp.Accounts do
  alias MyApp.{Repo, Events}

  def create_user(attrs) do
    Repo.transaction(fn ->
      with {:ok, user} <- Repo.insert(changeset),
           {:ok, _jobs} <- Events.emit(:user_created, %{
             user_id: user.id,
             email: user.email
           }) do
        {:ok, user}
      end
    end)
  end
end
```

## How It Works

```mermaid
flowchart TD
    A[Business Logic] -->|1. emit event + data| B[Events.emit]
    B -->|2. lookup handlers| C[Create Oban jobs]
    C -->|3. transaction commits| D[Oban processes jobs]
    D -->|4. dispatch| E[EmailHandler]
    D -->|4. dispatch| F[AnalyticsHandler]
```

Each `emit` call builds one `ObanEvents.Event` and enqueues one job per handler. All handlers of that emission receive the same event, including its `event_id`.

## The Event Struct

Handlers receive an `%ObanEvents.Event{}` with the following fields:

- `event_id` - Unique ID (UUID) of the emission, shared by all its handlers. Handy as an idempotency key
- `event_name` - The event atom (e.g., `:user_created`)
- `data` - The event payload, always with string keys
- `emitted_at` - UTC `DateTime` of the emission
- `causation_id` - `event_id` of the event that caused this one (or `nil`)
- `correlation_id` - ID shared by every event in the same chain. Defaults to the event's own `event_id`
- `metadata` - Custom JSON-serializable map (actor, request ID, source, ...), always with string keys

### Adding Metadata

Pass options as the third argument to `emit`:

```elixir
MyApp.Events.emit(:user_created, %{user_id: user.id},
  metadata: %{actor_id: current_user.id, request_id: Logger.metadata()[:request_id]}
)
```

### Chaining Events

When a handler emits a follow-up event, use `ObanEvents.Event.caused_by/2` to link them. The new event's `causation_id` is set to the parent's `event_id`, and the `correlation_id` is carried over:

```elixir
def handle_event(:order_placed, %Event{} = event) do
  MyApp.Events.emit(
    :invoice_requested,
    %{order_id: event.data["order_id"]},
    Event.caused_by(event, metadata: %{source: "order_handler"})
  )

  :ok
end
```

> Jobs enqueued before this metadata existed are still processed. Their `event_id`, `emitted_at`, `causation_id`, and `correlation_id` are `nil` and `metadata` is `%{}`.

## Configuration Options

When using `ObanEvents`, you can configure:

- `:oban` - Oban instance module (default: `Oban`)
- `:queue` - Oban queue name (default: `:events`)
- `:max_attempts` - Maximum retry attempts (default: `3`)
- `:priority` - Job priority, 0-3, lower is higher priority (default: `2`)

```elixir
defmodule MyApp.Events do
  use ObanEvents,
    oban: MyApp.Oban,           # Use custom Oban instance
    queue: :my_events,          # Custom queue name
    max_attempts: 5,            # Retry up to 5 times
    priority: 1                 # Higher priority than default

  @event_handlers %{
    # ...
  }
end
```

## API

Your event bus module provides these functions:

### `emit/3`

Emit an event to all registered handlers.

```elixir
@spec emit(atom(), map(), keyword()) :: {:ok, [Oban.Job.t()]}

# Raises ArgumentError if event is not registered
MyApp.Events.emit(:user_created, %{user_id: 123, email: "user@example.com"})

# With metadata / causation
MyApp.Events.emit(:user_created, %{user_id: 123},
  metadata: %{source: "admin"},
  causation_id: parent_event.event_id,
  correlation_id: parent_event.correlation_id
)
```

Options:

- `:metadata` - Custom JSON-serializable map (default: `%{}`)
- `:causation_id` - `event_id` of the causing event (default: `nil`)
- `:correlation_id` - Correlation ID of the event chain (default: the new `event_id`)

### `get_handlers!/1`

Get all handlers registered for an event.

```elixir
@spec get_handlers!(atom()) :: [module()]

MyApp.Events.get_handlers!(:user_created)
# => [MyApp.EmailHandler, MyApp.AnalyticsHandler]
```

### `all_events/0`

List all registered event names.

```elixir
@spec all_events() :: [atom()]

MyApp.Events.all_events()
# => [:user_created, :user_updated, :order_placed]
```

### `registered?/1`

Check if an event is registered.

```elixir
@spec registered?(atom()) :: boolean()

MyApp.Events.registered?(:user_created)
# => true
```

## Handler Implementation

Handlers must implement the `handle_event/2` callback, which receives the event name and an `ObanEvents.Event`:

```elixir
defmodule MyApp.AnalyticsHandler do
  use ObanEvents.Handler

  alias ObanEvents.Event

  @impl true
  def handle_event(:user_created, %Event{data: data, metadata: metadata}) do
    %{"user_id" => user_id} = data
    MyApp.Analytics.track("User Created", user_id: user_id, source: metadata["source"])
    :ok
  end

  @impl true
  def handle_event(:user_updated, %Event{data: data}) do
    %{"user_id" => user_id, "changes" => changes} = data
    MyApp.Analytics.track("User Updated", user_id: user_id, changes: changes)
    :ok
  end

  # Ignore other events
  @impl true
  def handle_event(_event_name, _event), do: :ok
end
```

### Return Values

Handlers should return:

- `:ok` - Event processed successfully
- `{:ok, result}` - Event processed successfully with a result
- `{:error, reason}` - Event processing failed (will trigger Oban retry)

Handlers may also raise exceptions, which will trigger Oban's retry mechanism.

## Best Practices

### 1. Always Use Transactions

Emit events within transactions to ensure atomicity:

```elixir
Repo.transaction(fn ->
  with {:ok, user} <- Repo.insert(changeset),
       {:ok, _jobs} <- Events.emit(:user_created, %{user_id: user.id}) do
    {:ok, user}
  end
end)
# If insert fails, emit never happens ✅
# If emit fails, transaction rolls back ✅
```

### 2. Make Handlers Idempotent

Handlers may be retried. Design them to be safe to run multiple times. The `event_id` is stable across retries and can serve as an idempotency key:

```elixir
def handle_event(:user_created, %Event{data: %{"user_id" => user_id}}) do
  # Use upsert instead of insert to handle retries
  %UserProfile{user_id: user_id}
  |> Repo.insert(
    on_conflict: :nothing,
    conflict_target: :user_id
  )

  :ok
end
```

### 3. Include All Necessary Data

Don't rely on database lookups for data that might change:

```elixir
# Good: Include all data needed
Events.emit(:status_changed, %{
  record_id: record.id,
  old_status: old_status,
  new_status: record.status
})

# Bad: Handler has to query DB (old_status might be wrong)
Events.emit(:status_changed, %{
  record_id: record.id
})
```

### 4. Use JSON-Serializable Data

Event data must be JSON-serializable (no PIDs, refs, or functions):

```elixir
# Good
Events.emit(:user_created, %{
  user_id: user.id,
  email: user.email,
  amount: Decimal.to_string(user.balance)
})

# Bad: Full struct is not reliably serializable
Events.emit(:user_created, %{user: user})
```

### 5. Pattern Match on Specific Events

Only handle events you care about:

```elixir
def handle_event(:user_created, event), do: # handle
def handle_event(:user_updated, event), do: # handle
def handle_event(_other, _event), do: :ok  # ignore rest
```

### 6. Return Errors for Retriable Failures

```elixir
def handle_event(:send_notification, %Event{data: data}) do
  case NotificationService.send(data) do
    {:ok, _} -> :ok
    {:error, :rate_limited} -> {:error, :rate_limited}  # Will retry
    {:error, :invalid_data} -> :ok  # Don't retry invalid data
  end
end
```

## Handler Management

### Renaming Handler Modules

Handler module names are serialized to the database as fully-qualified Elixir module atoms (e.g., `"Elixir.MyApp.EmailHandler"`). When you rename a handler module, existing queued jobs will still reference the old module name and will fail when Oban tries to execute them.

**Safe Renaming Strategy:**

Use a module alias to maintain backward compatibility:

```elixir
# After renaming MyApp.EmailHandler to MyApp.Notifications.EmailHandler

# 1. Create the new module with your desired name
defmodule MyApp.Notifications.EmailHandler do
  use ObanEvents.Handler

  @impl true
  def handle_event(:user_created, event) do
    # Your handler logic
    :ok
  end
end

# 2. Keep the old module as an alias
defmodule MyApp.EmailHandler do
  @moduledoc false
  defdelegate handle_event(event_name, event), to: MyApp.Notifications.EmailHandler
end

# 3. Update your event registry to use the new name
defmodule MyApp.Events do
  use ObanEvents

  @event_handlers %{
    user_created: [
      MyApp.Notifications.EmailHandler  # New jobs use new name
    ]
  }
end
```

**How This Works:**

1. **Existing queued jobs** call `MyApp.EmailHandler.handle_event/2`, which delegates to the new module
2. **New jobs** are created with `MyApp.Notifications.EmailHandler`
3. **Zero downtime** - both old and new jobs work correctly

**Cleanup:**

After all old jobs have processed (check Oban Web UI), you can safely remove the alias module. This typically takes as long as your retry window (default: a few hours with exponential backoff).

## Testing

`ObanEvents.Testing` provides helpers for asserting emitted events and exercising handlers. It takes the same options as `use Oban.Testing` and can be used alongside it:

```elixir
defmodule MyApp.AccountsTest do
  use MyApp.DataCase
  use ObanEvents.Testing, repo: MyApp.Repo
end
```

This defines `assert_event_emitted/1,2,3`, `refute_event_emitted/1,2,3`, `all_emitted_events/0,1` and `perform_event/2,3,4` in your test module and imports `build_event/1,2,3`.

### Testing Event Emission

The emission helpers inspect enqueued jobs, so Oban must run in `testing: :manual` mode (or wrap the test in `Oban.Testing.with_testing_mode(:manual, fn -> ... end)`):

```elixir
test "emits user_created event" do
  {:ok, user} = Accounts.create_user(%{email: "test@example.com"})

  # Data and metadata are matched as subsets; atom and string keys are interchangeable
  event = assert_event_emitted(:user_created, %{user_id: user.id})
  assert event.metadata["source"] == "signup"

  assert_event_emitted(:user_created, %{}, metadata: %{source: "signup"})
  refute_event_emitted(:user_deleted)
end

test "order handler requests an invoice" do
  order_event = assert_event_emitted(:order_placed)

  assert_event_emitted(:invoice_requested, %{}, causation_id: order_event.event_id)
end
```

`assert_event_emitted` also accepts `:event_id`, `:causation_id` and `:correlation_id` options, and returns the matching `ObanEvents.Event`. `all_emitted_events/1` returns one event per emission, regardless of how many handlers it was dispatched to.

You can still assert on the underlying jobs with `Oban.Testing`:

```elixir
assert_enqueued(
  worker: ObanEvents.DispatchWorker,
  args: %{
    "event" => "user_created",
    "handler" => "Elixir.MyApp.EmailHandler",
    "data" => %{"user_id" => user.id}
  }
)
```

### Testing Handlers

Use `build_event/3` to get an event exactly as a handler receives it (string keys, JSON-compatible values):

```elixir
test "EmailHandler sends welcome email" do
  event = build_event(:user_created, %{user_id: 123, email: "test@example.com"})

  assert :ok = MyApp.EmailHandler.handle_event(:user_created, event)
  assert_email_sent(to: "test@example.com", subject: "Welcome!")
end
```

Or use `perform_event/4` to run a handler through `ObanEvents.DispatchWorker`, just like in production:

```elixir
test "EmailHandler returns an error when the mailer is down" do
  assert {:error, :unavailable} =
           perform_event(MyApp.EmailHandler, :user_created, %{email: "test@example.com"},
             metadata: %{source: "test"}
           )
end
```

### Testing with Oban Inline Mode

For integration tests, configure Oban to execute jobs inline:

```elixir
# config/test.exs
config :my_app, Oban,
  testing: :inline,
  queues: false,
  plugins: false

# In test
test "creates user and sends email" do
  {:ok, user} = Accounts.create_user(%{email: "test@example.com"})

  # Email sent immediately in test mode
  assert_email_sent(to: "test@example.com")
end
```

## Observability

### Oban Web UI

View event processing history, errors, and retries:

```elixir
# In router.ex (development only)
import Phoenix.LiveDashboard.Router

scope "/dev" do
  pipe_through :browser
  live_dashboard "/dashboard", metrics: MyAppWeb.Telemetry

  forward "/oban", Oban.Web.Router
end
```

### Logging

ObanEvents logs all event processing:

```
[info] Processing event: user_created with handler: MyApp.EmailHandler
[info] Event processed successfully: user_created by MyApp.EmailHandler
[error] Event handler failed: user_created by MyApp.EmailHandler, error: :network_timeout
```

## Troubleshooting

### Events Not Processing

**Check Oban queue configuration:**

```elixir
# config/config.exs
config :my_app, Oban,
  repo: MyApp.Repo,
  queues: [
    events: 10  # Make sure your queue is configured
  ]
```

**Check job status in database:**

```sql
SELECT * FROM oban_jobs
WHERE queue = 'events'
ORDER BY inserted_at DESC
LIMIT 10;
```

### Events Not Emitted

**Verify event is registered:**

```elixir
iex> MyApp.Events.registered?(:user_created)
true

iex> MyApp.Events.all_events()
[:user_created, :user_updated, ...]
```

**Check transaction succeeded:**

Add logging to verify the transaction completes:

```elixir
Repo.transaction(fn ->
  with {:ok, user} <- Repo.insert(changeset),
       {:ok, jobs} <- Events.emit(:user_created, data) do
    Logger.info("Emitted #{length(jobs)} jobs")
    {:ok, user}
  end
end)
```

### Handler Failures

**View errors in Oban Web UI** at `/dev/oban`

**Check application logs** for handler errors

**Manually retry failed job:**

```elixir
iex> job = Oban.Job |> Repo.get(job_id)
iex> Oban.retry_job(job)
```

## Examples

See the [test suite](test/) for complete examples of:
- Event emission
- Handler implementation
- Transaction behavior
- Testing patterns

## License

MIT License - see [LICENSE](LICENSE) for details.

## Credits

Built with [Oban](https://github.com/sorentwo/oban) by Parker Selbert.
