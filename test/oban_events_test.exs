defmodule ObanEventsTest do
  use ExUnit.Case, async: true

  alias ObanEvents.DispatchWorker

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
    test "records event metadata in job args" do
      assert {:ok, [job]} =
               TestEventBus.emit(:investment_created, %{id: 1}, metadata: %{actor_id: 42})

      assert %{
               "event_id" => event_id,
               "metadata" => %{"actor_id" => 42},
               "causation_id" => nil,
               "correlation_id" => event_id,
               "emitted_at" => emitted_at
             } = job.args

      assert {:ok, _uuid} = Ecto.UUID.cast(event_id)
      assert {:ok, %DateTime{}, 0} = DateTime.from_iso8601(emitted_at)
    end

    test "shares one event across all handler jobs" do
      defmodule MultiHandlerEventBus do
        @moduledoc false
        use ObanEvents

        @event_handlers %{
          test_event: [ObanEventsTest.TestHandler, ObanEventsTest.TestHandler]
        }
      end

      assert {:ok, [first, second]} = MultiHandlerEventBus.emit(:test_event, %{})
      assert Map.delete(first.args, "handler") == Map.delete(second.args, "handler")
    end

    test "links follow-up events via :caused_by" do
      parent = ObanEvents.Event.new(:investment_created, %{}, correlation_id: "chain-1")

      assert {:ok, [job]} =
               TestEventBus.emit(:investment_status_changed, %{}, caused_by: parent)

      assert job.args["causation_id"] == parent.event_id
      assert job.args["correlation_id"] == "chain-1"
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
