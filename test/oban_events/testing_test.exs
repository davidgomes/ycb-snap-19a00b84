defmodule ObanEvents.TestingTest do
  use ExUnit.Case, async: true

  import ObanEvents.Testing

  alias ObanEvents.Event

  test "build_event/2 fills generated metadata" do
    event = build_event(%{"user_id" => 123})

    assert %Event{data: %{"user_id" => 123}, causation_id: nil, correlation_id: nil} = event
    assert is_binary(event.event_id)
    assert is_binary(event.idempotency_key)
    assert event.event_id != event.idempotency_key
  end

  test "build_event/2 accepts metadata overrides" do
    event =
      build_event(%{"user_id" => 123},
        event_id: "evt-1",
        idempotency_key: "idem-1",
        causation_id: "parent-event",
        correlation_id: "corr-123"
      )

    assert event == %Event{
             data: %{"user_id" => 123},
             event_id: "evt-1",
             idempotency_key: "idem-1",
             causation_id: "parent-event",
             correlation_id: "corr-123"
           }
  end
end
