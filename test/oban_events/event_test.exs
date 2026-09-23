defmodule ObanEvents.EventTest do
  use ExUnit.Case, async: true

  alias ObanEvents.Event

  describe "new/3" do
    test "builds an event with defaults" do
      event = Event.new(:user_created, %{user_id: 1})

      assert event.name == :user_created
      assert event.data == %{user_id: 1}
      assert event.metadata == %{}
      assert {:ok, _} = Ecto.UUID.cast(event.id)
      assert %DateTime{time_zone: "Etc/UTC"} = event.emitted_at
      assert event.causation_id == nil
      assert event.correlation_id == event.id
    end

    test "accepts explicit options" do
      emitted_at = ~U[2025-01-01 00:00:00Z]

      event =
        Event.new(:user_created, %{},
          id: "event-1",
          metadata: %{actor_id: 2},
          emitted_at: emitted_at,
          causation_id: "cause-1",
          correlation_id: "corr-1"
        )

      assert event.id == "event-1"
      assert event.metadata == %{actor_id: 2}
      assert event.emitted_at == emitted_at
      assert event.causation_id == "cause-1"
      assert event.correlation_id == "corr-1"
    end

    test "caused_by derives causation_id and correlation_id" do
      root = Event.new(:order_placed, %{})
      child = Event.new(:invoice_requested, %{}, caused_by: root)
      grandchild = Event.new(:invoice_sent, %{}, caused_by: child)

      assert child.causation_id == root.id
      assert child.correlation_id == root.id
      assert grandchild.causation_id == child.id
      assert grandchild.correlation_id == root.id
    end

    test "caused_by falls back to the parent id when it has no correlation_id" do
      parent = %Event{id: "parent-1", name: :legacy, data: %{}}

      event = Event.new(:follow_up, %{}, caused_by: parent)

      assert event.causation_id == "parent-1"
      assert event.correlation_id == "parent-1"
    end

    test "explicit ids take precedence over caused_by" do
      parent = Event.new(:order_placed, %{})

      event =
        Event.new(:invoice_requested, %{},
          caused_by: parent,
          causation_id: "cause-1",
          correlation_id: "corr-1"
        )

      assert event.causation_id == "cause-1"
      assert event.correlation_id == "corr-1"
    end

    test "raises on invalid options" do
      assert_raise ArgumentError, fn -> Event.new(:user_created, %{}, unknown: 1) end

      assert_raise ArgumentError, ~r/:metadata must be a map/, fn ->
        Event.new(:user_created, %{}, metadata: "nope")
      end

      assert_raise ArgumentError, ~r/:caused_by must be/, fn ->
        Event.new(:user_created, %{}, caused_by: %{id: "x"})
      end
    end
  end

  describe "to_args/1 and from_args/1" do
    test "round-trips an event" do
      event =
        Event.new(:user_created, %{"user_id" => 1},
          metadata: %{"actor_id" => 2},
          causation_id: "cause-1"
        )

      args = Event.to_args(event)

      assert args["event"] == "user_created"
      assert args["event_id"] == event.id
      assert args["emitted_at"] == DateTime.to_iso8601(event.emitted_at)
      assert Event.from_args(args) == event
    end

    test "from_args/1 handles args without metadata fields" do
      event = Event.from_args(%{"event" => "user_created", "data" => %{"a" => 1}})

      assert event == %Event{
               id: nil,
               name: :user_created,
               data: %{"a" => 1},
               metadata: %{},
               emitted_at: nil,
               causation_id: nil,
               correlation_id: nil
             }
    end

    test "from_args/1 ignores an unparseable emitted_at" do
      event =
        Event.from_args(%{"event" => "user_created", "data" => %{}, "emitted_at" => "garbage"})

      assert event.emitted_at == nil
    end
  end
end
