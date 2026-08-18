defmodule ObanEvents.EventTest do
  use ExUnit.Case, async: true

  alias ObanEvents.Event

  describe "new/1, new/2, new/3" do
    test "creates an event struct with name and data" do
      event = Event.new(:user_created, %{user_id: 123, email: "user@example.com"})

      assert %Event{} = event
      assert event.name == :user_created
      assert event.data == %{user_id: 123, email: "user@example.com"}
      assert is_binary(event.id)
      assert event.id =~ ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
      assert %DateTime{} = event.timestamp
      assert event.correlation_id == nil
      assert event.causation_id == nil
      assert event.metadata == %{}
    end

    test "creates an event with keyword options" do
      custom_id = "custom-id-123"
      custom_time = ~U[2026-08-18 12:00:00Z]

      event =
        Event.new(:order_placed, %{order_id: 456},
          id: custom_id,
          timestamp: custom_time,
          correlation_id: "corr-1",
          causation_id: "cause-1",
          metadata: %{tenant_id: "acme", ip: "127.0.0.1"}
        )

      assert event.id == custom_id
      assert event.name == :order_placed
      assert event.data == %{order_id: 456}
      assert event.timestamp == custom_time
      assert event.correlation_id == "corr-1"
      assert event.causation_id == "cause-1"
      assert event.metadata == %{tenant_id: "acme", ip: "127.0.0.1"}
    end

    test "creates an event with map options (atom or string keys)" do
      event =
        Event.new(:order_placed, %{order_id: 456}, %{
          "id" => "custom-id-str",
          "correlation_id" => "corr-2",
          "causation_id" => "cause-2",
          "metadata" => %{"actor_id" => 99}
        })

      assert event.id == "custom-id-str"
      assert event.correlation_id == "corr-2"
      assert event.causation_id == "cause-2"
      assert event.metadata == %{"actor_id" => 99}
    end

    test "creates an event from attributes map" do
      event =
        Event.new(%{
          name: :user_updated,
          data: %{user_id: 789},
          correlation_id: "corr-attrs",
          metadata: %{source: "api"}
        })

      assert event.name == :user_updated
      assert event.data == %{user_id: 789}
      assert event.correlation_id == "corr-attrs"
      assert event.metadata == %{source: "api"}
      assert is_binary(event.id)
    end

    test "creates an event from keyword list" do
      event =
        Event.new(
          name: :user_updated,
          data: %{user_id: 789},
          correlation_id: "corr-kw"
        )

      assert event.name == :user_updated
      assert event.data == %{user_id: 789}
      assert event.correlation_id == "corr-kw"
    end
  end

  describe "to_map/1 and from_map/1 serialization" do
    test "serializes event to map with string keys and ISO8601 timestamp" do
      timestamp = ~U[2026-08-18 12:00:00Z]

      event =
        Event.new(:user_created, %{user_id: 123},
          id: "test-id-123",
          timestamp: timestamp,
          correlation_id: "corr-123",
          causation_id: "cause-123",
          metadata: %{actor_id: 1}
        )

      map = Event.to_map(event)

      assert map == %{
               "id" => "test-id-123",
               "event" => "user_created",
               "data" => %{user_id: 123},
               "timestamp" => "2026-08-18T12:00:00Z",
               "correlation_id" => "corr-123",
               "causation_id" => "cause-123",
               "metadata" => %{actor_id: 1}
             }
    end

    test "deserializes from map back to Event struct" do
      map = %{
        "id" => "test-id-123",
        "event" => "user_created",
        "data" => %{"user_id" => 123},
        "timestamp" => "2026-08-18T12:00:00Z",
        "correlation_id" => "corr-123",
        "causation_id" => "cause-123",
        "metadata" => %{"actor_id" => 1}
      }

      event = Event.from_map(map)

      assert %Event{} = event
      assert event.id == "test-id-123"
      assert event.name == :user_created
      assert event.data == %{"user_id" => 123}
      assert event.timestamp == ~U[2026-08-18 12:00:00Z]
      assert event.correlation_id == "corr-123"
      assert event.causation_id == "cause-123"
      assert event.metadata == %{"actor_id" => 1}
    end
  end
end
