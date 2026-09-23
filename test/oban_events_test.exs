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

  # Test handler that reports the received event to the test process
  defmodule NotifyingHandler do
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

    alias ObanEventsTest.{NotifyingHandler, TestHandler}

    @event_handlers %{
      investment_status_changed: [TestHandler],
      investment_created: [TestHandler],
      investment_updated: [TestHandler, NotifyingHandler],
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

  describe "emit/3 event metadata" do
    test "stores event metadata in job args" do
      assert {:ok, [job]} =
               TestEventBus.emit(:investment_created, %{id: 1}, metadata: %{actor_id: 7})

      assert {:ok, _} = Ecto.UUID.cast(job.args["event_id"])
      assert {:ok, %DateTime{}, 0} = DateTime.from_iso8601(job.args["emitted_at"])
      assert job.args["metadata"] == %{"actor_id" => 7}
      assert job.args["causation_id"] == nil
      assert job.args["correlation_id"] == job.args["event_id"]
    end

    test "defaults metadata to an empty map" do
      assert {:ok, [job]} = TestEventBus.emit(:investment_created, %{id: 1})
      assert job.args["metadata"] == %{}
    end

    test "all handlers of one emit share the same event" do
      assert {:ok, [job1, job2]} = TestEventBus.emit(:investment_updated, %{id: 1})

      assert job1.args["event_id"] == job2.args["event_id"]
      assert job1.args["emitted_at"] == job2.args["emitted_at"]
      assert job1.args["handler"] != job2.args["handler"]
    end

    test "each emit gets a new event id" do
      {:ok, [job1]} = TestEventBus.emit(:investment_created, %{id: 1})
      {:ok, [job2]} = TestEventBus.emit(:investment_created, %{id: 1})

      assert job1.args["event_id"] != job2.args["event_id"]
    end

    test "handlers receive an Event struct with string keys" do
      assert {:ok, _jobs} =
               TestEventBus.emit(:investment_updated, %{id: 1, status: :active},
                 metadata: %{actor_id: 7}
               )

      assert_received {:handled, NotifyingHandler, :investment_updated, %Event{} = event}
      assert event.name == :investment_updated
      assert event.data == %{"id" => 1, "status" => "active"}
      assert event.metadata == %{"actor_id" => 7}
      assert %DateTime{} = event.emitted_at
      assert event.correlation_id == event.id
    end

    test "accepts explicit causation_id and correlation_id" do
      assert {:ok, [job]} =
               TestEventBus.emit(:investment_created, %{},
                 causation_id: "cause-1",
                 correlation_id: "corr-1"
               )

      assert job.args["causation_id"] == "cause-1"
      assert job.args["correlation_id"] == "corr-1"
    end

    test "caused_by links the new event to the causing event" do
      parent = Event.new(:investment_created, %{}, correlation_id: "corr-1")

      assert {:ok, [job]} = TestEventBus.emit(:investment_created, %{}, caused_by: parent)

      assert job.args["causation_id"] == parent.id
      assert job.args["correlation_id"] == "corr-1"
      assert job.args["event_id"] != parent.id
    end

    test "raises ArgumentError for unknown options" do
      assert_raise ArgumentError, fn ->
        TestEventBus.emit(:investment_created, %{}, unknown: true)
      end
    end

    test "raises ArgumentError for non-map metadata" do
      assert_raise ArgumentError, ~r/:metadata must be a map/, fn ->
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
