defmodule ObanEvents.TestingTest do
  use ExUnit.Case, async: true

  import ObanEvents.Testing

  alias ObanEvents.Event

  doctest ObanEvents.Testing, import: true

  defmodule GreetingHandler do
    @moduledoc false
    use ObanEvents.Handler

    @impl true
    def handle_event(:user_created, %Event{data: %{"name" => name}}), do: {:ok, "Hello, #{name}"}
  end

  describe "build_event/2" do
    test "builds an Event with generated event_id and idempotency_key" do
      event = build_event(%{"user_id" => 123})

      assert %Event{data: %{"user_id" => 123}, causation_id: nil, correlation_id: nil} = event
      assert {:ok, _} = Ecto.UUID.cast(event.event_id)
      assert {:ok, _} = Ecto.UUID.cast(event.idempotency_key)
      assert event.event_id != event.idempotency_key
    end

    test "generates new IDs for every event" do
      first = build_event(%{})
      second = build_event(%{})

      assert first.event_id != second.event_id
      assert first.idempotency_key != second.idempotency_key
    end

    test "converts data to the JSON shape handlers receive" do
      event = build_event(%{user_id: 123, profile: %{role: :admin, tags: [:a, "b"]}})

      assert event.data == %{
               "user_id" => 123,
               "profile" => %{"role" => "admin", "tags" => ["a", "b"]}
             }
    end

    test "accepts overrides for every metadata field" do
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
      assert_raise ArgumentError, ~r/unknown keys \[:causation\]/, fn ->
        build_event(%{}, causation: "causation-id")
      end
    end

    test "builds events that can be passed directly to handlers" do
      assert {:ok, "Hello, Ada"} =
               GreetingHandler.handle_event(:user_created, build_event(%{name: "Ada"}))
    end
  end
end
