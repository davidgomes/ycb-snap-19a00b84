defmodule ObanEvents.TestingTest do
  use ExUnit.Case, async: true

  import ObanEvents.Testing

  alias ObanEvents.Event

  describe "build_event/1" do
    test "builds an Event with generated ids and nil optional metadata" do
      event = build_event(%{"user_id" => 123})

      assert %Event{
               data: %{"user_id" => 123},
               causation_id: nil,
               correlation_id: nil
             } = event

      assert is_binary(event.event_id)
      assert is_binary(event.idempotency_key)
      assert event.event_id != event.idempotency_key
    end

    test "generates unique ids by default" do
      first = build_event(%{})
      second = build_event(%{})

      assert first.event_id != second.event_id
      assert first.idempotency_key != second.idempotency_key
    end
  end

  describe "build_event/2" do
    test "overrides metadata fields when provided" do
      event =
        build_event(
          %{"user_id" => 123},
          event_id: "custom-event-id",
          idempotency_key: "custom-key",
          causation_id: "parent-event",
          correlation_id: "corr-123"
        )

      assert event == %Event{
               data: %{"user_id" => 123},
               event_id: "custom-event-id",
               idempotency_key: "custom-key",
               causation_id: "parent-event",
               correlation_id: "corr-123"
             }
    end

    test "requires data to be a map" do
      assert_raise FunctionClauseError, fn ->
        build_event("not a map")
      end
    end
  end
end
