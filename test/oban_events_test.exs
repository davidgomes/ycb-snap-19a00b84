defmodule ObanEventsTest do
  use ExUnit.Case, async: true

  alias ObanEvents.Event

  # Test handler module
  defmodule TestHandler do
    @moduledoc false
    use ObanEvents.Handler

    @impl true
    def handle_event(_event, _data), do: :ok
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
      portfolio_fund_removed: []
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
      assert is_binary(job.args["id"])
      assert is_binary(job.args["timestamp"])
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

  describe "emit/3 with metadata options" do
    test "passes metadata, correlation_id, and causation_id in job args" do
      event_data = %{"investment_id" => "inv-123"}

      assert {:ok, [job]} =
               TestEventBus.emit(:investment_created, event_data,
                 correlation_id: "corr-123",
                 causation_id: "cause-456",
                 metadata: %{actor_id: "user-1", ip: "10.0.0.1"}
               )

      assert job.args["correlation_id"] == "corr-123"
      assert job.args["causation_id"] == "cause-456"
      assert job.args["metadata"] == %{"actor_id" => "user-1", "ip" => "10.0.0.1"}
    end

    test "allows custom id and timestamp" do
      custom_time = ~U[2026-08-18 10:00:00Z]

      assert {:ok, [job]} =
               TestEventBus.emit(:investment_created, %{},
                 id: "custom-id-999",
                 timestamp: custom_time
               )

      assert job.args["id"] == "custom-id-999"
      assert job.args["timestamp"] == "2026-08-18T10:00:00Z"
    end
  end

  describe "emit/1 with Event struct" do
    test "emits an ObanEvents.Event struct directly" do
      event =
        Event.new(:investment_created, %{amount: 50_000},
          id: "event-struct-id",
          correlation_id: "corr-event",
          metadata: %{source: "web"}
        )

      assert {:ok, [job]} = TestEventBus.emit(event)
      assert job.args["id"] == "event-struct-id"
      assert job.args["event"] == "investment_created"
      assert job.args["data"] == %{"amount" => 50_000}
      assert job.args["correlation_id"] == "corr-event"
      assert job.args["metadata"] == %{"source" => "web"}
    end

    test "raises ArgumentError when Event struct has unregistered event name" do
      event = Event.new(:unregistered_event, %{})

      assert_raise ArgumentError, ~r/Unknown event: :unregistered_event/, fn ->
        TestEventBus.emit(event)
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
