defmodule ObanEventsTest do
  use ExUnit.Case, async: true

  alias ObanEvents.DispatchWorker
  alias ObanEvents.Event

  # Test handler module
  defmodule TestHandler do
    @moduledoc false
    use ObanEvents.Handler

    @impl true
    def handle_event(_event_name, _event), do: :ok
  end

  # Inline Oban testing runs jobs in the emitting process, so handled events
  # can be sent back to the test.
  defmodule RecordingHandler do
    @moduledoc false
    use ObanEvents.Handler

    @impl true
    def handle_event(event_name, event) do
      send(self(), {:handled, event_name, event})
      :ok
    end
  end

  # Test event bus with handlers registered (uses defaults)
  defmodule TestEventBus do
    @moduledoc false
    use ObanEvents

    alias ObanEventsTest.{RecordingHandler, TestHandler}

    @event_handlers %{
      investment_status_changed: [TestHandler],
      investment_created: [TestHandler],
      investor_registered: [TestHandler, RecordingHandler],
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
    test "shares one event_id across all handler jobs of an emit" do
      assert {:ok, [job_one, job_two]} = TestEventBus.emit(:investor_registered, %{"id" => 1})

      assert {:ok, _} = Ecto.UUID.cast(job_one.args["event_id"])
      assert job_one.args["event_id"] == job_two.args["event_id"]
    end

    test "generates a new event_id for every emit" do
      assert {:ok, [first]} = TestEventBus.emit(:investment_created, %{"id" => 1})
      assert {:ok, [second]} = TestEventBus.emit(:investment_created, %{"id" => 1})

      assert first.args["event_id"] != second.args["event_id"]
    end

    test "generates a unique idempotency_key for each handler job" do
      assert {:ok, [job_one, job_two]} = TestEventBus.emit(:investor_registered, %{"id" => 1})

      assert {:ok, _} = Ecto.UUID.cast(job_one.args["idempotency_key"])
      assert {:ok, _} = Ecto.UUID.cast(job_two.args["idempotency_key"])
      assert job_one.args["idempotency_key"] != job_two.args["idempotency_key"]
    end

    test "stores causation_id and correlation_id in the job args" do
      assert {:ok, [job]} =
               TestEventBus.emit(:investment_created, %{"id" => 1},
                 causation_id: "parent-event-id",
                 correlation_id: "operation-id"
               )

      assert job.args["causation_id"] == "parent-event-id"
      assert job.args["correlation_id"] == "operation-id"
    end

    test "defaults causation_id and correlation_id to nil" do
      assert {:ok, [job]} = TestEventBus.emit(:investment_created, %{"id" => 1})

      assert job.args["causation_id"] == nil
      assert job.args["correlation_id"] == nil
    end

    test "delivers an Event with string-keyed data and metadata to handlers" do
      assert {:ok, jobs} =
               TestEventBus.emit(:investor_registered, %{investor_id: 42},
                 causation_id: "parent-event-id",
                 correlation_id: "operation-id"
               )

      recording_job =
        Enum.find(jobs, &(&1.args["handler"] == Atom.to_string(RecordingHandler)))

      assert_received {:handled, :investor_registered, %Event{} = event}

      assert event == %Event{
               data: %{"investor_id" => 42},
               event_id: recording_job.args["event_id"],
               idempotency_key: recording_job.args["idempotency_key"],
               causation_id: "parent-event-id",
               correlation_id: "operation-id"
             }
    end

    test "raises ArgumentError for unknown options" do
      assert_raise ArgumentError, ~r/unknown keys \[:trace_id\]/, fn ->
        TestEventBus.emit(:investment_created, %{"id" => 1}, trace_id: "abc")
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
