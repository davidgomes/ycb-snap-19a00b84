defmodule ObanEvents.TestingTest do
  use ExUnit.Case, async: true

  import ObanEvents.Testing

  alias ObanEvents.Event

  test "build_event/2 fills generated metadata" do
    event = build_event(%{"user_id" => 123})

    assert %Event{data: %{"user_id" => 123}, causation_id: nil, correlation_id: nil} = event
    assert event.event_id =~ ~r/^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/
    assert event.idempotency_key =~
             ~r/^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/
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
