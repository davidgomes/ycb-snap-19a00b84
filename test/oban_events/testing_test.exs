defmodule ObanEvents.TestingTest do
  use ExUnit.Case, async: true

  import ObanEvents.Testing

  alias ObanEvents.Event

  doctest ObanEvents.Testing, import: true

  describe "build_event/2" do
    test "wraps data in an Event with generated metadata" do
      assert %Event{
               data: %{"user_id" => 123},
               event_id: event_id,
               idempotency_key: idempotency_key,
               causation_id: nil,
               correlation_id: nil
             } = build_event(%{"user_id" => 123})

      assert_uuidv7(event_id)
      assert_uuidv7(idempotency_key)
      assert event_id != idempotency_key
    end

    test "normalizes data the way handlers receive it" do
      event = build_event(%{user_id: 123, status: :active, tags: [:a], profile: %{name: "Ada"}})

      assert event.data == %{
               "user_id" => 123,
               "status" => "active",
               "tags" => ["a"],
               "profile" => %{"name" => "Ada"}
             }
    end

    test "generates different metadata for each call" do
      first = build_event(%{})
      second = build_event(%{})

      assert first.event_id != second.event_id
      assert first.idempotency_key != second.idempotency_key
    end

    test "accepts metadata overrides" do
      event =
        build_event(%{},
          event_id: "event-id",
          idempotency_key: "idempotency-key",
          causation_id: "causation-id",
          correlation_id: "correlation-id"
        )

      assert event.event_id == "event-id"
      assert event.idempotency_key == "idempotency-key"
      assert event.causation_id == "causation-id"
      assert event.correlation_id == "correlation-id"
    end

    test "raises ArgumentError for unknown options" do
      assert_raise ArgumentError, ~r/unknown keys \[:correlation\]/, fn ->
        build_event(%{}, correlation: "typo")
      end
    end

    test "requires data to be a map" do
      assert_raise FunctionClauseError, fn ->
        build_event("not a map")
      end
    end
  end

  defp assert_uuidv7(value) do
    assert value =~ ~r/^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/
  end
end
