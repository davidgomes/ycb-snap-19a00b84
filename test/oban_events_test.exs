defmodule ObanEventsTest do
  use ExUnit.Case, async: true

  alias ObanEvents.DispatchWorker
  alias ObanEvents.Event

  # Test handler module
  defmodule TestHandler do
    @moduledoc false
    use ObanEvents.Handler

    @impl true
    def handle_event(_event, _data), do: :ok
  end

  defmodule RecordingHandler do
    @moduledoc false
    use ObanEvents.Handler

    @impl true
    def handle_event(event_name, event) do
      send(self(), {:handled, __MODULE__, event_name, event})
      :ok
    end
  end

  defmodule OtherRecordingHandler do
    @moduledoc false
    use ObanEvents.Handler

    @impl true
    def handle_event(event_name, event) do
      send(self(), {:handled, __MODULE__, event_name, event})
      :ok
    end
  end

  # Test event bus with handlers registered (uses defaults)
  defmodule TestEventBus do
    @moduledoc false
    use ObanEvents

    alias ObanEventsTest.TestHandler

    @event_handlers %{
      investment_status_changed: [TestHandler],
      investment_created: [TestHandler],
      investment_cancelled: [],
      portfolio_company_added: [],
      portfolio_company_removed: [],
      portfolio_fund_added: [],
      portfolio_fund_removed: [],
      recorded_event: [RecordingHandler, OtherRecordingHandler]
    }
  end

  # Test event bus with custom configuration
  defmodule CustomConfigEventBus do
    @moduledoc false
    use ObanEvents,
      queue: :custom_queue,
      max_attempts: 10,
      priority: 0

    @event_handlers %{
      test_event: [ObanEventsTest.TestHandler]
    }
  end

  describe "emit/2" do
    test "creates Oban jobs for registered event handlers" do
      event_data = %{
        "investment_id" => Ecto.UUID.generate(),
        "account_id" => Ecto.UUID.generate(),
        "old_status" => "pending",
        "new_status" => "active_closed"
      }

      # emit/2 now returns {:ok, jobs} consistently in test and production
      assert {:ok, jobs} = TestEventBus.emit(:investment_status_changed, event_data)
      assert length(jobs) == 1

      # Verify job was executed with correct data
      [job] = jobs
      assert job.worker == "ObanEvents.DispatchWorker"
      assert job.state == "completed"
      assert job.args["event"] == "investment_status_changed"
      assert job.args["handler"] == "Elixir.ObanEventsTest.TestHandler"
      assert job.args["data"] == event_data
    end

    test "creates multiple jobs when multiple handlers are registered" do
      event_data = %{
        "investment_id" => Ecto.UUID.generate(),
        "account_id" => Ecto.UUID.generate()
      }

      # investment_created has one handler currently
      assert {:ok, jobs} = TestEventBus.emit(:investment_created, event_data)
      assert length(jobs) == 1
    end

    test "raises ArgumentError for unregistered events" do
      assert_raise ArgumentError, ~r/Unknown event: :unknown_event/, fn ->
        TestEventBus.emit(:unknown_event, %{"data" => "value"})
      end
    end

    # Note: Transaction behavior (emit within Ecto.Repo.transaction, rollback, etc.)
    # should be tested in the consuming application with its specific Repo setup.
    # ObanEvents.emit/2 uses Oban.insert_all which participates in the current
    # transaction if one exists, but we don't test that here since this library
    # doesn't provide its own Repo.

    test "requires event_name to be an atom" do
      assert_raise FunctionClauseError, fn ->
        TestEventBus.emit("string_event", %{})
      end
    end

    test "requires data to be a map" do
      assert_raise FunctionClauseError, fn ->
        TestEventBus.emit(:event_name, "not a map")
      end
    end
  end

  describe "emit/3 event metadata" do
    test "stores event id, emission time, and metadata in job args" do
      assert {:ok, [job]} =
               TestEventBus.emit(:investment_created, %{"investment_id" => 1},
                 metadata: %{actor_id: 7, request_id: "req-1"}
               )

      assert {:ok, _} = Ecto.UUID.cast(job.args["event_id"])
      assert {:ok, %DateTime{}, 0} = DateTime.from_iso8601(job.args["emitted_at"])
      assert job.args["metadata"] == %{"actor_id" => 7, "request_id" => "req-1"}
    end

    test "defaults metadata to an empty map" do
      assert {:ok, [job]} = TestEventBus.emit(:investment_created, %{"investment_id" => 1})

      assert job.args["metadata"] == %{}
    end

    test "handlers receive an Event struct with string-keyed data and metadata" do
      assert {:ok, _jobs} =
               TestEventBus.emit(:recorded_event, %{user_id: 1}, metadata: %{actor_id: 2})

      assert_received {:handled, RecordingHandler, :recorded_event, %Event{} = event}
      assert event.name == :recorded_event
      assert event.data == %{"user_id" => 1}
      assert event.metadata == %{"actor_id" => 2}
      assert %DateTime{} = event.emitted_at
      assert event.attempt == 1
    end

    test "all handlers of one emission share the event id and emission time" do
      assert {:ok, [_, _]} = TestEventBus.emit(:recorded_event, %{})

      assert_received {:handled, RecordingHandler, :recorded_event, event}
      assert_received {:handled, OtherRecordingHandler, :recorded_event, other_event}
      assert is_binary(event.id)
      assert event.id == other_event.id
      assert event.emitted_at == other_event.emitted_at
    end

    test "each emission gets a new event id" do
      assert {:ok, [first | _]} = TestEventBus.emit(:recorded_event, %{})
      assert {:ok, [second | _]} = TestEventBus.emit(:recorded_event, %{})

      assert first.args["event_id"] != second.args["event_id"]
    end

    test "raises ArgumentError when metadata is not a map" do
      assert_raise ArgumentError, ~r/expected :metadata to be a map/, fn ->
        TestEventBus.emit(:investment_created, %{}, metadata: [actor_id: 1])
      end
    end
  end

  describe "configuration" do
    test "uses default configuration when not specified" do
      assert {:ok, jobs} = TestEventBus.emit(:investment_created, %{"test" => "data"})

      [job] = jobs
      # Defaults: queue: :events, max_attempts: 3, priority: 2
      assert job.queue == "events"
      assert job.max_attempts == 3
      assert job.priority == 2
    end

    test "uses custom configuration when specified" do
      assert {:ok, jobs} = CustomConfigEventBus.emit(:test_event, %{"test" => "data"})

      [job] = jobs
      # Custom: queue: :custom_queue, max_attempts: 10, priority: 0
      assert job.queue == "custom_queue"
      assert job.max_attempts == 10
      assert job.priority == 0
    end
  end
end
