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
- 🏷️ **Traceable** - Every event carries an id, timestamp, metadata, and causation/correlation ids
- 🧪 **Testable** - Helpers for testing handlers and asserting on emitted events

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

  @impl true
  def handle_event(:user_created, %ObanEvents.Event{data: data}) do
    %{"user_id" => user_id, "email" => email} = data

    Logger.info("Sending welcome email to #{email}")
    MyApp.Mailer.send_welcome_email(email)

    :ok
  end

  @impl true
  def handle_event(_event_name, _event), do: :ok
end
```

Handlers receive the event name and an [`ObanEvents.Event`](#event-struct) struct holding the data and metadata.

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
    A[Business Logic] -->|1. emit event + data + metadata| B[Events.emit]
    B -->|2. lookup handlers| C[Create Oban jobs]
    C -->|3. transaction commits| D[Oban processes jobs]
    D -->|4. dispatch| E[EmailHandler]
    D -->|4. dispatch| F[AnalyticsHandler]
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

```elixir
@spec emit(atom(), map(), keyword()) :: {:ok, [Oban.Job.t()]}

# Raises ArgumentError if event is not registered
MyApp.Events.emit(:user_created, %{user_id: 123, email: "user@example.com"})

# With metadata
MyApp.Events.emit(:user_created, %{user_id: 123}, metadata: %{actor_id: admin.id})
```

Options:

- `:metadata` - Map of additional, JSON-serializable metadata (default: `%{}`)
- `:caused_by` - Parent `%ObanEvents.Event{}`; links this event to it (see [Event Chains](#event-chains))
- `:causation_id` / `:correlation_id` - Set the ids explicitly (override `:caused_by`)

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

## Event Struct

Each `emit/3` call builds one `ObanEvents.Event`, shared by every handler job for that emission:

```elixir
%ObanEvents.Event{
  event_id: "0b6f8b0e-...",          # UUID, unique per emission
  name: :user_created,
  data: %{"user_id" => 123},          # always string keys
  metadata: %{"actor_id" => 1},       # always string keys, defaults to %{}
  causation_id: nil,                  # event_id of the event that caused this one
  correlation_id: "0b6f8b0e-...",     # shared by all events in a chain
  emitted_at: ~U[2026-01-01 12:00:00.000000Z]
}
```

Jobs enqueued before metadata was recorded are still delivered, with `nil` ids and timestamp and empty `metadata`.

### Event Chains

When a handler emits a follow-up event, pass the event it is handling as `:caused_by`. The new event's `causation_id` is set to the parent's `event_id`, and its `correlation_id` is inherited, so the whole chain can be traced back to the first event:

```elixir
def handle_event(:user_created, %ObanEvents.Event{data: %{"user_id" => user_id}} = event) do
  MyApp.Mailer.send_welcome_email(user_id)
  {:ok, _jobs} = MyApp.Events.emit(:welcome_email_sent, %{user_id: user_id}, caused_by: event)
  :ok
end
```

## Handler Implementation

Handlers must implement the `handle_event/2` callback, which receives the event name and the `ObanEvents.Event`:

```elixir
defmodule MyApp.AnalyticsHandler do
  use ObanEvents.Handler

  @impl true
  def handle_event(:user_created, %ObanEvents.Event{data: data, metadata: metadata}) do
    %{"user_id" => user_id} = data
    MyApp.Analytics.track("User Created", user_id: user_id, actor_id: metadata["actor_id"])
    :ok
  end

  @impl true
  def handle_event(:user_updated, %ObanEvents.Event{data: data}) do
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

Handlers may be retried. Design them to be safe to run multiple times. `event.event_id` is stable across retries and makes a good idempotency key:

```elixir
def handle_event(:user_created, %ObanEvents.Event{data: %{"user_id" => user_id}}) do
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
def handle_event(:send_notification, %ObanEvents.Event{data: data}) do
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

`ObanEvents.Testing` provides helpers for testing both sides of the event bus.

### Testing Event Emission

With Oban in `:manual` testing mode, `use ObanEvents.Testing` with your repo:

```elixir
# config/test.exs
config :my_app, Oban, testing: :manual

# In test
use ObanEvents.Testing, repo: MyApp.Repo

test "emits user_created event" do
  {:ok, user} = Accounts.create_user(%{email: "test@example.com"})

  assert_event_emitted(:user_created, data: %{user_id: user.id})
  assert_event_emitted(:user_created, handler: MyApp.EmailHandler, metadata: %{source: "api"})
  refute_event_emitted(:user_deleted)

  assert [%ObanEvents.Event{data: %{"email" => "test@example.com"}}] =
           all_emitted_events(:user_created)
end
```

`assert_event_emitted/2` and `refute_event_emitted/2` accept `:data` and `:metadata` (partial, deep match; atom keys are fine), `:handler`, `:causation_id`, and `:correlation_id`. `all_emitted_events/2` returns one `%ObanEvents.Event{}` per emission, not per handler job.

### Testing Handlers

`build_event/3` builds the event exactly as a handler receives it (data and metadata JSON round-tripped, so keys are strings). `perform_event/4` runs a handler through the dispatch worker without inserting a job. Neither needs a database:

```elixir
import ObanEvents.Testing

test "EmailHandler sends welcome email" do
  event = build_event(:user_created, %{user_id: 123, email: "test@example.com"})

  assert :ok = MyApp.EmailHandler.handle_event(:user_created, event)
  assert_email_sent(to: "test@example.com", subject: "Welcome!")
end

test "EmailHandler through the dispatch worker" do
  assert :ok = perform_event(MyApp.EmailHandler, :user_created, %{user_id: 123})
end
```

Both accept the same options as `emit/3` (`:metadata`, `:caused_by`, ...).

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
