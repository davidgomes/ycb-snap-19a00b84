defmodule ObanEventsTest do
  use ExUnit.Case, async: true

  alias ObanEvents.DispatchWorker
  alias ObanEvents.Event

  # Test handler module
  defmodule TestHandler do
    @moduledoc false
    use ObanEvents.Handler

    @impl true
    def handle_event(event_name, %Event{} = event) do
      send(self(), {:handled, __MODULE__, event_name, event})
      :ok
    end
  end

  defmodule OtherTestHandler do
    @moduledoc false
    use ObanEvents.Handler

    @impl true
    def handle_event(event_name, %Event{} = event) do
      send(self(), {:handled, __MODULE__, event_name, event})
      :ok
    end
  end

  # Test event bus with handlers registered (uses defaults)
  defmodule TestEventBus do
    @moduledoc false
    use ObanEvents

    alias ObanEventsTest.{OtherTestHandler, TestHandler}

    @event_handlers %{
      investment_status_changed: [TestHandler],
      investment_created: [TestHandler],
      investment_updated: [TestHandler, OtherTestHandler],
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

  describe "emit/3 metadata" do
    test "handlers receive an Event with the data and metadata" do
      causation_id = UUIDv7.generate()
      correlation_id = UUIDv7.generate()

      assert {:ok, [job]} =
               TestEventBus.emit(:investment_created, %{investment_id: 1},
                 causation_id: causation_id,
                 correlation_id: correlation_id
               )

      assert_received {:handled, TestHandler, :investment_created, %Event{} = event}
      assert event.data == %{"investment_id" => 1}
      assert event.event_id == job.args["event_id"]
      assert event.idempotency_key == job.args["idempotency_key"]
      assert event.causation_id == causation_id
      assert event.correlation_id == correlation_id
    end

    test "generates UUIDv7 event_id and idempotency_key" do
      assert {:ok, [job]} = TestEventBus.emit(:investment_created, %{})

      assert_uuidv7(job.args["event_id"])
      assert_uuidv7(job.args["idempotency_key"])
    end

    test "shares event_id across handler jobs of one emit, with a unique idempotency_key per job" do
      assert {:ok, [job_a, job_b]} = TestEventBus.emit(:investment_updated, %{})

      assert job_a.args["event_id"] == job_b.args["event_id"]
      assert job_a.args["idempotency_key"] != job_b.args["idempotency_key"]

      assert_received {:handled, TestHandler, :investment_updated, %Event{} = event_a}
      assert_received {:handled, OtherTestHandler, :investment_updated, %Event{} = event_b}
      assert event_a.event_id == event_b.event_id
      assert event_a.idempotency_key != event_b.idempotency_key
    end

    test "generates a new event_id for each emit" do
      assert {:ok, [first]} = TestEventBus.emit(:investment_created, %{})
      assert {:ok, [second]} = TestEventBus.emit(:investment_created, %{})

      assert first.args["event_id"] != second.args["event_id"]
    end

    test "defaults causation_id and correlation_id to nil" do
      assert {:ok, [job]} = TestEventBus.emit(:investment_created, %{})

      assert job.args["causation_id"] == nil
      assert job.args["correlation_id"] == nil

      assert_received {:handled, TestHandler, :investment_created,
                       %Event{causation_id: nil, correlation_id: nil}}
    end

    test "raises ArgumentError for unknown options" do
      assert_raise ArgumentError, ~r/unknown keys \[:correlation\]/, fn ->
        TestEventBus.emit(:investment_created, %{}, correlation: "typo")
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

  defp assert_uuidv7(value) do
    assert value =~ ~r/^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/
  end
end
