defmodule ObanEvents.TestingTest do
  use ExUnit.Case, async: true

  import ObanEvents.Testing

  alias ObanEvents.Event

  defmodule GreetingHandler do
    @moduledoc false
    use ObanEvents.Handler

    @impl true
    def handle_event(:user_created, %Event{data: %{"name" => name}}), do: {:ok, "Hello, #{name}"}
  end

  describe "build_event/2" do
    test "builds an Event with generated event_id and idempotency_key" do
      assert %Event{data: %{"user_id" => 123}} = event = build_event(%{"user_id" => 123})

      assert {:ok, _} = Ecto.UUID.cast(event.event_id)
      assert {:ok, _} = Ecto.UUID.cast(event.idempotency_key)
      assert event.event_id != event.idempotency_key
      assert event.causation_id == nil
      assert event.correlation_id == nil
    end

    test "generates new IDs for every call" do
      first = build_event(%{})
      second = build_event(%{})

      assert first.event_id != second.event_id
      assert first.idempotency_key != second.idempotency_key
    end

    test "serializes data like Oban job args" do
      event = build_event(%{user_id: 123, status: :active, tags: [:new], profile: %{age: 30}})

      assert event.data == %{
               "user_id" => 123,
               "status" => "active",
               "tags" => ["new"],
               "profile" => %{"age" => 30}
             }
    end

    test "accepts metadata overrides" do
      event =
        build_event(%{},
          event_id: "event-id",
          idempotency_key: "idempotency-key",
          causation_id: "causation-id",
          correlation_id: "correlation-id"
        )

      assert event == %Event{
               data: %{},
               event_id: "event-id",
               idempotency_key: "idempotency-key",
               causation_id: "causation-id",
               correlation_id: "correlation-id"
             }
    end

    test "raises ArgumentError for unknown options" do
      assert_raise ArgumentError, ~r/unknown keys \[:trace_id\]/, fn ->
        build_event(%{}, trace_id: "abc")
      end
    end

    test "can be passed directly to a handler" do
      assert {:ok, "Hello, Ada"} =
               GreetingHandler.handle_event(:user_created, build_event(%{name: "Ada"}))
    end
  end
end
