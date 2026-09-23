defmodule ObanEvents.TestingTest do
  use ExUnit.Case, async: true

  import ObanEvents.Testing

  alias ObanEvents.Event

  describe "build_event/2" do
    test "wraps data and generates event_id and idempotency_key" do
      event = build_event(%{"user_id" => 123})

      assert %Event{data: %{"user_id" => 123}, causation_id: nil, correlation_id: nil} = event
      assert {:ok, _} = Ecto.UUID.cast(event.event_id)
      assert {:ok, _} = Ecto.UUID.cast(event.idempotency_key)
      assert event.event_id != event.idempotency_key
    end

    test "defaults to empty data" do
      assert %Event{data: %{}} = build_event()
    end

    test "converts data keys to strings like runtime dispatch" do
      event = build_event(%{user_id: 123, profile: %{name: "Ada"}, tags: [%{id: 1}]})

      assert event.data == %{
               "user_id" => 123,
               "profile" => %{"name" => "Ada"},
               "tags" => [%{"id" => 1}]
             }
    end

    test "accepts metadata overrides" do
      event =
        build_event(%{},
          event_id: "event-id",
          idempotency_key: "key",
          causation_id: "parent-event-id",
          correlation_id: "correlation-id"
        )

      assert event == %Event{
               data: %{},
               event_id: "event-id",
               idempotency_key: "key",
               causation_id: "parent-event-id",
               correlation_id: "correlation-id"
             }
    end

    test "raises ArgumentError for unknown options" do
      assert_raise ArgumentError, fn -> build_event(%{}, unknown: "value") end
    end
  end
end
