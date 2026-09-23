defmodule ObanEvents.TestingTest do
  use ExUnit.Case, async: true

  import ObanEvents.Testing

  alias ObanEvents.Event

  defmodule TestHandler do
    @moduledoc false
    use ObanEvents.Handler

    @impl true
    def handle_event(:user_created, %Event{data: %{"user_id" => user_id}, causation_id: cause}) do
      {:ok, {user_id, cause}}
    end
  end

  describe "build_event/2" do
    test "wraps data and generates event_id and idempotency_key" do
      event = build_event(%{"user_id" => 123})

      assert %Event{data: %{"user_id" => 123}, causation_id: nil, correlation_id: nil} = event
      assert is_binary(event.event_id)
      assert is_binary(event.idempotency_key)
      assert event.event_id != event.idempotency_key
    end

    test "generates new IDs on every call" do
      first = build_event(%{})
      second = build_event(%{})

      assert first.event_id != second.event_id
      assert first.idempotency_key != second.idempotency_key
    end

    test "accepts metadata overrides" do
      event =
        build_event(%{"user_id" => 123},
          event_id: "event-1",
          idempotency_key: "key-1",
          causation_id: "parent-1",
          correlation_id: "corr-1"
        )

      assert event == %Event{
               data: %{"user_id" => 123},
               event_id: "event-1",
               idempotency_key: "key-1",
               causation_id: "parent-1",
               correlation_id: "corr-1"
             }
    end

    test "raises ArgumentError for unknown options" do
      assert_raise ArgumentError, ~r/unknown keys \[:unknown\]/, fn ->
        build_event(%{}, unknown: "value")
      end
    end

    test "requires data to be a map" do
      assert_raise FunctionClauseError, fn ->
        build_event("not a map")
      end
    end

    test "builds events that can be passed directly to handlers" do
      event = build_event(%{"user_id" => 123}, causation_id: "parent-1")

      assert {:ok, {123, "parent-1"}} = TestHandler.handle_event(:user_created, event)
    end
  end

  describe "Event.generate_id/0" do
    test "returns a UUIDv7 string" do
      id = Event.generate_id()

      assert id =~ ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/
    end

    test "encodes the current time in the first 48 bits" do
      before = System.system_time(:millisecond)
      id = Event.generate_id()
      after_generation = System.system_time(:millisecond)

      {timestamp, ""} = id |> String.replace("-", "") |> String.slice(0, 12) |> Integer.parse(16)

      assert timestamp >= before
      assert timestamp <= after_generation
    end
  end
end
