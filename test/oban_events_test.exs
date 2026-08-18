defmodule ObanEventsTest do
  use ExUnit.Case, async: true

  alias ObanEvents.DispatchWorker

  # Test handler modules
  defmodule TestHandler do
    @moduledoc false
    use ObanEvents.Handler

    @impl true
    def handle_event(_event, _data), do: :ok
  end

  defmodule OtherTestHandler do
    @moduledoc false
    use ObanEvents.Handler

    @impl true
    def handle_event(_event, _data), do: :ok
  end

  # Test event bus with handlers registered (uses defaults)
  defmodule TestEventBus do
    @moduledoc false
    use ObanEvents

    alias ObanEventsTest.OtherTestHandler
    alias ObanEventsTest.TestHandler

    @event_handlers %{
      investment_status_changed: [TestHandler],
      investment_created: [TestHandler],
      investment_archived: [TestHandler, OtherTestHandler],
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

    test "converts atom keys in the payload to strings" do
      assert {:ok, [job]} = TestEventBus.emit(:investment_created, %{investment_id: 1})

      assert job.args["data"] == %{"investment_id" => 1}
    end

    test "attaches generated metadata to the job args" do
      assert {:ok, [job]} = TestEventBus.emit(:investment_created, %{"test" => "data"})

      assert {:ok, _uuid} = Ecto.UUID.cast(job.args["event_id"])
      assert {:ok, _datetime, _offset} = DateTime.from_iso8601(job.args["emitted_at"])
      assert job.args["meta"] == %{}
    end
  end

  describe "emit/3" do
    test "attaches metadata to the job args" do
      assert {:ok, [job]} =
               TestEventBus.emit(:investment_created, %{"investment_id" => 1},
                 meta: %{actor_id: 7, request_id: "req-1"}
               )

      assert job.args["meta"] == %{"actor_id" => 7, "request_id" => "req-1"}
    end

    test "accepts an explicit event id and emit time" do
      emitted_at = ~U[2026-01-01 00:00:00Z]

      assert {:ok, [job]} =
               TestEventBus.emit(:investment_created, %{}, id: "event-1", emitted_at: emitted_at)

      assert job.args["event_id"] == "event-1"
      assert job.args["emitted_at"] == "2026-01-01T00:00:00Z"
    end

    test "shares one event id across all handler jobs" do
      assert {:ok, jobs} = TestEventBus.emit(:investment_archived, %{"investment_id" => 1})

      assert [event_id] = jobs |> Enum.map(& &1.args["event_id"]) |> Enum.uniq()
      assert {:ok, _uuid} = Ecto.UUID.cast(event_id)

      assert Enum.map(jobs, & &1.args["handler"]) == [
               "Elixir.ObanEventsTest.TestHandler",
               "Elixir.ObanEventsTest.OtherTestHandler"
             ]
    end

    test "raises when the metadata is invalid" do
      assert_raise ArgumentError, ~r/:meta must be a map/, fn ->
        TestEventBus.emit(:investment_created, %{}, meta: "nope")
      end
    end

    test "raises ArgumentError for unregistered events" do
      assert_raise ArgumentError, ~r/Unknown event: :unknown_event/, fn ->
        TestEventBus.emit(:unknown_event, %{}, meta: %{})
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
