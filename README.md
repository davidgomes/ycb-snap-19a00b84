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
- 🧭 **Traceable** - Event IDs, idempotency keys, and causation/correlation metadata on every event

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

Implement the `ObanEvents.Handler` behaviour. Handlers receive an `ObanEvents.Event` struct with your data plus metadata:

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

## Event Metadata

Handlers receive an `ObanEvents.Event` struct containing your data plus metadata for deduplication, tracing, and correlation:

```elixir
%ObanEvents.Event{
  data: %{"user_id" => 123},                                 # Your event data (string keys)
  event_id: "9b1f0c1e-4f8e-4a3b-9a57-2f1d8c6e7b21",          # Unique per emit
  idempotency_key: "c3a4e5f6-1b2c-4d3e-8f9a-0b1c2d3e4f5a",   # Unique per job
  causation_id: "5e6f7a8b-9c0d-4e1f-a2b3-c4d5e6f7a8b9",      # Optional: parent event_id
  correlation_id: "0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d"     # Optional: business operation grouping
}
```

### `event_id` - Event Identity

- **Generated**: Once per `emit` call
- **Shared**: All handlers for the same emit get the same `event_id`
- **Use**: Identify the emit, and pass it as `causation_id` to child events

```elixir
def handle_event(:user_created, %Event{event_id: id, data: data}) do
  Events.emit(:send_welcome_email, data, causation_id: id)
end
```

### `idempotency_key` - Job Deduplication

- **Generated**: Once per handler job, stable across Oban retries
- **Use**: Deduplicate side effects (outbox tables, external APIs)

```elixir
def handle_event(:send_email, %Event{idempotency_key: key, data: data}) do
  %EmailOutbox{idempotency_key: key, to: data["email"]}
  |> Repo.insert(on_conflict: :nothing, conflict_target: :idempotency_key)

  :ok
end
```

### `causation_id` - Event Chains (Optional)

- **Provided**: Pass the parent's `event_id` when emitting
- **Use**: Build audit trails and answer "why did this happen?"

```elixir
# user_registered        (event_id: "evt-001", causation_id: nil)
# └─> send_welcome_email (event_id: "evt-002", causation_id: "evt-001")
#     └─> email_delivered (event_id: "evt-003", causation_id: "evt-002")
```

### `correlation_id` - Business Operation Grouping (Optional)

- **Provided**: Generate one and pass it to every related emit
- **Use**: Group all events from a single business operation

```elixir
correlation_id = Ecto.UUID.generate()

Events.emit(:subscription_upgraded, data, correlation_id: correlation_id)
Events.emit(:payment_processed, data, correlation_id: correlation_id)
Events.emit(:invoice_generated, data, correlation_id: correlation_id)
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

### `emit/3`

Emit an event to all registered handlers.

Options:

- `:causation_id` - `event_id` of the parent event that caused this emit
- `:correlation_id` - Identifier grouping events of one business operation

```elixir
@spec emit(atom(), map(), keyword()) :: {:ok, [Oban.Job.t()]}

# Raises ArgumentError if event is not registered or an option is unknown
MyApp.Events.emit(:user_created, %{user_id: 123, email: "user@example.com"})
MyApp.Events.emit(:user_created, %{user_id: 123}, correlation_id: correlation_id)
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

Handlers must implement the `handle_event/2` callback, which receives the event name and an `ObanEvents.Event` struct:

```elixir
defmodule MyApp.AnalyticsHandler do
  use ObanEvents.Handler

  alias ObanEvents.Event

  @impl true
  def handle_event(:user_created, %Event{data: data}) do
    %{"user_id" => user_id} = data
    MyApp.Analytics.track("User Created", user_id: user_id)
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

Handlers may be retried. Design them to be safe to run multiple times, using `idempotency_key` when there is no natural unique key:

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

### Testing Event Emission

```elixir
use Oban.Testing, repo: MyApp.Repo

test "emits user_created event" do
  {:ok, user} = Accounts.create_user(%{email: "test@example.com"})

  assert_enqueued(
    worker: ObanEvents.DispatchWorker,
    args: %{
      "event" => "user_created",
      "handler" => "Elixir.MyApp.EmailHandler",
      "data" => %{"user_id" => user.id}
    }
  )
end
```

### Testing Handlers

Use `ObanEvents.Testing.build_event/2` to build an `Event` struct without filling in every metadata field. It generates `event_id` and `idempotency_key`, and converts data keys to strings to match what handlers receive at runtime:

```elixir
import ObanEvents.Testing

test "EmailHandler sends welcome email" do
  event = build_event(%{user_id: 123, email: "test@example.com"})

  assert :ok = MyApp.EmailHandler.handle_event(:user_created, event)
  assert_email_sent(to: "test@example.com", subject: "Welcome!")
end
```

Override any metadata field when a handler depends on it:

```elixir
event =
  build_event(%{"user_id" => 123},
    event_id: "event-id",
    idempotency_key: "idempotency-key",
    causation_id: "parent-event-id",
    correlation_id: "correlation-id"
  )
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

`event_id`, `causation_id`, and `correlation_id` are set as Logger metadata while a handler runs. Add them to your formatter to filter logs by event chain or business operation:

```elixir
config :logger, :console,
  metadata: [:event_id, :causation_id, :correlation_id]
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
