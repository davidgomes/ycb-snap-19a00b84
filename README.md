# ObanEvents

A lightweight, persistent event bus for Elixir applications built on top of [Oban](https://github.com/sorentwo/oban).

## Features

- 🔒 **Persistent** - Events survive application restarts (stored in Oban's database)
- 🔄 **Reliable** - Automatic retries on failure via Oban
- ⚡ **Async** - Non-blocking execution of handlers
- 🔗 **Transactional** - Works within database transactions for atomicity
- 🏷️ **Event Metadata** - Built-in support for event IDs, timestamps, correlation IDs, causation IDs, and custom metadata
- 🧪 **Testing Helpers** - Dedicated test helpers (`assert_event_emitted`, `refute_event_emitted`, `all_emitted_events`)
- 📊 **Observable** - Track event processing via Oban Web UI and structured logs
- ✅ **Type-safe** - Compile-time validation of events
- 🎯 **Decoupled** - Event emitters don't know about handlers

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

```elixir
defmodule MyApp.EmailHandler do
  use ObanEvents.Handler

  require Logger

  # Handle event with payload data (handle_event/2)
  @impl true
  def handle_event(:user_created, data) do
    %{"user_id" => user_id, "email" => email} = data

    Logger.info("Sending welcome email to #{email}")
    MyApp.Mailer.send_welcome_email(email)

    :ok
  end

  # Or access the full ObanEvents.Event struct and metadata (handle_event/3)
  @impl true
  def handle_event(:order_placed, data, %ObanEvents.Event{} = event) do
    Logger.info("Processing order for correlation ID: #{event.correlation_id}")
    # Access metadata: event.metadata, event.id, event.timestamp, event.causation_id
    :ok
  end

  @impl true
  def handle_event(_event, _data), do: :ok
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

  def update_user(user, attrs) do
    # Emit with metadata (correlation ID, causation ID, custom metadata)
    Events.emit(:user_updated, %{user_id: user.id},
      correlation_id: "req-12345",
      causation_id: "cmd-67890",
      metadata: %{actor_id: user.id, ip: "127.0.0.1"}
    )
  end
end
```

## How It Works

```mermaid
flowchart TD
    A[Business Logic] -->|1. emit event + metadata| B[Events.emit]
    B -->|2. lookup handlers| C[Create Oban jobs with Event metadata]
    C -->|3. transaction commits| D[Oban processes jobs]
    D -->|4. dispatch| E[EmailHandler.handle_event]
    D -->|4. dispatch| F[AnalyticsHandler.handle_event]
```

## Event Struct & Metadata

Events in `ObanEvents` can carry rich contextual metadata represented by the `ObanEvents.Event` struct.

### Fields

- `id` - Unique event identifier string (auto-generated UUID v4 if not provided).
- `name` - Atom representing the event name (e.g. `:user_created`).
- `data` - Map containing the event payload.
- `timestamp` - `DateTime` representing when the event occurred (defaults to `DateTime.utc_now()`, serialized as ISO8601).
- `correlation_id` - Optional string to track a distributed transaction or workflow across multiple events.
- `causation_id` - Optional string tracking the command or parent event ID that caused this event.
- `metadata` - Map of arbitrary contextual metadata (e.g. `%{actor_id: 1, ip: "127.0.0.1", tenant_id: "acme"}`).

### Creating and Emitting Event Structs

You can create `ObanEvents.Event` structs manually or pass options directly to `emit/3`:

```elixir
alias ObanEvents.Event

# Create with Event.new/2 or Event.new/3
event = Event.new(:user_created, %{user_id: 123},
  correlation_id: "corr-123",
  causation_id: "cause-456",
  metadata: %{actor_id: "user-1", ip: "127.0.0.1"}
)

# Emit the struct directly
MyApp.Events.emit(event)

# Or emit with metadata options via emit/3
MyApp.Events.emit(:user_created, %{user_id: 123},
  correlation_id: "corr-123",
  metadata: %{actor_id: "user-1"}
)
```

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

### `emit/1`

Emit an `ObanEvents.Event` struct.

```elixir
@spec emit(ObanEvents.Event.t()) :: {:ok, [Oban.Job.t()]}

event = ObanEvents.Event.new(:user_created, %{user_id: 123}, correlation_id: "corr-1")
MyApp.Events.emit(event)
```

### `emit/2`

Emit an event by name with data map to all registered handlers.

```elixir
@spec emit(atom(), map()) :: {:ok, [Oban.Job.t()]}

# Raises ArgumentError if event is not registered
MyApp.Events.emit(:user_created, %{user_id: 123, email: "user@example.com"})
```

### `emit/3`

Emit an event with data map and additional metadata options.

```elixir
@spec emit(atom(), map(), keyword() | map()) :: {:ok, [Oban.Job.t()]}

MyApp.Events.emit(:user_created, %{user_id: 123},
  id: "custom-id-123",
  correlation_id: "req-abc",
  causation_id: "cmd-xyz",
  metadata: %{source: "admin_panel"}
)
```

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

Handlers implement the `ObanEvents.Handler` behaviour with either `handle_event/2` or `handle_event/3`:

```elixir
defmodule MyApp.AnalyticsHandler do
  use ObanEvents.Handler

  # Basic callback with event name and payload data
  @impl true
  def handle_event(:user_created, data) do
    %{"user_id" => user_id} = data
    MyApp.Analytics.track("User Created", user_id: user_id)
    :ok
  end

  # Extended callback with access to Event struct and metadata
  @impl true
  def handle_event(:user_updated, data, %ObanEvents.Event{} = event) do
    %{"user_id" => user_id, "changes" => changes} = data
    MyApp.Analytics.track("User Updated",
      user_id: user_id,
      changes: changes,
      correlation_id: event.correlation_id,
      metadata: event.metadata
    )
    :ok
  end

  # Catch-all to ignore unhandled events
  @impl true
  def handle_event(_event, _data), do: :ok
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

Handlers may be retried. Design them to be safe to run multiple times:

```elixir
def handle_event(:user_created, %{"user_id" => user_id}) do
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

Event data and metadata must be JSON-serializable (no PIDs, refs, or functions):

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
def handle_event(:user_created, data), do: # handle
def handle_event(:user_updated, data), do: # handle
def handle_event(_other, _data), do: :ok  # ignore rest
```

### 6. Return Errors for Retriable Failures

```elixir
def handle_event(:send_notification, data) do
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
  def handle_event(:user_created, data) do
    # Your handler logic
    :ok
  end
end

# 2. Keep the old module as an alias
defmodule MyApp.EmailHandler do
  @moduledoc false
  defdelegate handle_event(event, data), to: MyApp.Notifications.EmailHandler
  defdelegate handle_event(event, data, meta), to: MyApp.Notifications.EmailHandler
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

1. **Existing queued jobs** call `MyApp.EmailHandler.handle_event`, which delegates to the new module
2. **New jobs** are created with `MyApp.Notifications.EmailHandler`
3. **Zero downtime** - both old and new jobs work correctly

**Cleanup:**

After all old jobs have processed (check Oban Web UI), you can safely remove the alias module. This typically takes as long as your retry window (default: a few hours with exponential backoff).

## Testing

`ObanEvents` provides dedicated testing helpers in `ObanEvents.Testing` that integrate smoothly with `Oban.Testing`.

### Using `ObanEvents.Testing`

Include `ObanEvents.Testing` in your test files or case templates:

```elixir
defmodule MyApp.AccountsTest do
  use ExUnit.Case
  use ObanEvents.Testing, repo: MyApp.Repo

  test "emits user_created event with payload" do
    {:ok, user} = MyApp.Accounts.create_user(%{email: "test@example.com"})

    # Assert event emitted by name
    assert_event_emitted(:user_created)

    # Assert event emitted with specific payload
    assert_event_emitted(:user_created, %{email: "test@example.com"})

    # Assert event emitted with specific metadata / handler
    assert_event_emitted(:user_created, %{email: "test@example.com"},
      handler: MyApp.EmailHandler,
      correlation_id: "req-123"
    )

    # Refute that unexpected events were emitted
    refute_event_emitted(:user_deleted)
    refute_event_emitted(:user_created, %{email: "other@example.com"})
  end
end
```

### Testing Helpers API

- **`assert_event_emitted(event_name, data \\ %{}, opts_or_timeout \\ :none)`**
  Asserts that an event matching the given name, payload data, and/or options (`:handler`, `:correlation_id`, `:causation_id`, `:metadata`, `:id`) is enqueued.
- **`refute_event_emitted(event_name, data \\ %{}, opts_or_timeout \\ :none)`**
  Refutes that a matching event was enqueued.
- **`all_emitted_events(opts \\ [])`**
  Returns a list of all enqueued events as `ObanEvents.Event` structs. Can be filtered by event name using `all_emitted_events(event: :user_created)`.

```elixir
test "inspecting all emitted events" do
  MyApp.Events.emit(:user_created, %{user_id: 123}, correlation_id: "corr-1")
  MyApp.Events.emit(:order_placed, %{order_id: 456})

  # Get all events as ObanEvents.Event structs
  events = all_emitted_events()
  assert length(events) == 2

  # Filter by event name
  [user_event] = all_emitted_events(event: :user_created)
  assert user_event.name == :user_created
  assert user_event.data == %{"user_id" => 123}
  assert user_event.correlation_id == "corr-1"
end
```

### Testing Handlers Directly

You can test handlers directly by invoking `handle_event/2` or `handle_event/3`:

```elixir
test "EmailHandler sends welcome email" do
  data = %{"user_id" => 123, "email" => "test@example.com"}

  assert :ok = MyApp.EmailHandler.handle_event(:user_created, data)
  assert_email_sent(to: "test@example.com", subject: "Welcome!")
end
```

### Testing with Oban Inline Mode

For integration tests where you want handlers to run synchronously and immediately:

```elixir
# config/test.exs
config :my_app, Oban,
  testing: :inline,
  queues: false,
  plugins: false

# In test
test "creates user and sends email immediately" do
  {:ok, user} = MyApp.Accounts.create_user(%{email: "test@example.com"})

  # Handler executed inline
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
- Event struct and metadata
- Testing helpers and assertions
- Event emission
- Handler implementation
- Transaction behavior

## License

MIT License - see [LICENSE](LICENSE) for details.

## Credits

Built with [Oban](https://github.com/sorentwo/oban) by Parker Selbert.
