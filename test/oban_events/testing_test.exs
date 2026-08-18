defmodule ObanEvents.TestingTest do
  use ExUnit.Case, async: true
  use ObanEvents.Testing, repo: ObanEvents.Test.Repo

  alias ObanEvents.Event

  defmodule TestHandler do
    @moduledoc false
    use ObanEvents.Handler

    @impl true
    def handle_event(_event, _data), do: :ok
  end

  defmodule OtherHandler do
    @moduledoc false
    use ObanEvents.Handler

    @impl true
    def handle_event(_event, _data), do: :ok
  end

  defmodule TestEventBus do
    @moduledoc false
    use ObanEvents

    @event_handlers %{
      user_registered: [ObanEvents.TestingTest.TestHandler],
      order_placed: [ObanEvents.TestingTest.TestHandler, ObanEvents.TestingTest.OtherHandler],
      item_removed: []
    }
  end

  describe "assert_event_emitted/1,2,3 in manual mode" do
    test "asserts event emitted by event name" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        TestEventBus.emit(:user_registered, %{user_id: 123})

        assert_event_emitted(:user_registered)
        assert_event_emitted(:user_registered, %{user_id: 123})
        refute_event_emitted(:user_registered, %{user_id: 999})
        refute_event_emitted(:order_placed)
      end)
    end

    test "asserts event emitted with metadata and options" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        TestEventBus.emit(:user_registered, %{user_id: 123},
          id: "evt-custom-id",
          correlation_id: "corr-100",
          causation_id: "cause-200",
          metadata: %{ip: "127.0.0.1"}
        )

        assert_event_emitted(:user_registered, %{user_id: 123},
          id: "evt-custom-id",
          correlation_id: "corr-100",
          causation_id: "cause-200",
          metadata: %{ip: "127.0.0.1"}
        )

        # Keyword list as 2nd arg without data
        assert_event_emitted(:user_registered, correlation_id: "corr-100")
        assert_event_emitted(:user_registered, id: "evt-custom-id")

        refute_event_emitted(:user_registered, %{user_id: 123}, correlation_id: "wrong")
        refute_event_emitted(:user_registered, correlation_id: "wrong")
      end)
    end

    test "asserts event emitted with specific handler" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        TestEventBus.emit(:order_placed, %{order_id: 456})

        assert_event_emitted(:order_placed, %{order_id: 456},
          handler: ObanEvents.TestingTest.TestHandler
        )

        assert_event_emitted(:order_placed, %{order_id: 456},
          handler: ObanEvents.TestingTest.OtherHandler
        )
      end)
    end

    test "all_emitted_events/1 returns list of Event structs" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        TestEventBus.emit(:user_registered, %{user_id: 123}, correlation_id: "corr-all")
        TestEventBus.emit(:order_placed, %{order_id: 456})

        events = all_emitted_events()
        assert length(events) == 3

        user_events = all_emitted_events(event: :user_registered)
        assert length(user_events) == 1
        [event] = user_events
        assert %Event{} = event
        assert event.name == :user_registered
        assert event.data == %{"user_id" => 123}
        assert event.correlation_id == "corr-all"
      end)
    end
  end
end
