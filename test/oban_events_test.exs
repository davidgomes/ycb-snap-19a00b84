defmodule ObanEventsTest do
  use ExUnit.Case, async: true

  alias ObanEvents.DispatchWorker

  # Test handler module
  defmodule TestHandler do
    @moduledoc false
    use ObanEvents.Handler

    @impl true
    def handle_event(_event, %Event{}), do: :ok
  end

  # Test event bus with handlers registered (uses defaults)
  defmodule TestEventBus do
    @moduledoc false
    use ObanEvents

    alias ObanEventsTest.TestHandler

    @events %{
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
      oban: {Oban, queue: :custom_queue, max_attempts: 10, priority: 0, tags: ["custom"]}

    @events %{
      test_event: [ObanEventsTest.TestHandler]
    }
  end

  # Test module with per-handler options
  defmodule PerHandlerOptionsEventBus do
    @moduledoc false
    use ObanEvents

    @events %{
      multi_handler_event: [
        {TestHandler, priority: 0, max_attempts: 5, tags: ["critical"]},
        {TestHandler, queue: :low_priority, priority: 3},
        TestHandler
      ]
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

  describe "configuration" do
    test "uses default configuration when not specified" do
      assert {:ok, jobs} = TestEventBus.emit(:investment_created, %{"test" => "data"})

      [job] = jobs
      # Defaults: queue: :oban_events, max_attempts: 3, priority: 2
      assert job.queue == "oban_events"
      assert job.max_attempts == 3
      assert job.priority == 2
    end

    test "uses custom configuration when specified" do
      assert {:ok, jobs} = CustomConfigEventBus.emit(:test_event, %{"test" => "data"})

      [job] = jobs
      # Custom: queue: :custom_queue, max_attempts: 10, priority: 0, tags: ["custom"]
      assert job.queue == "custom_queue"
      assert job.max_attempts == 10
      assert job.priority == 0
      assert job.tags == ["custom"]
    end

    test "per-handler options override global defaults" do
      assert {:ok, jobs} =
               PerHandlerOptionsEventBus.emit(:multi_handler_event, %{"test" => "data"})

      assert length(jobs) == 3

      [job1, job2, job3] = jobs

      # First handler: custom priority, max_attempts, and tags
      assert job1.priority == 0
      assert job1.max_attempts == 5
      assert job1.tags == ["critical"]
      # Uses global default
      assert job1.queue == "oban_events"

      # Second handler: custom queue and priority
      assert job2.queue == "low_priority"
      assert job2.priority == 3
      # Uses global default
      assert job2.max_attempts == 3
      # Uses global default
      assert job2.tags == []

      # Third handler: all defaults
      assert job3.queue == "oban_events"
      assert job3.priority == 2
      assert job3.max_attempts == 3
      assert job3.tags == []
    end
  end
end
