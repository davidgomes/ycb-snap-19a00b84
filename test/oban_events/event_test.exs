defmodule ObanEvents.EventTest do
  use ExUnit.Case, async: true

  alias ObanEvents.Event

  describe "new/3" do
    test "builds an event with a unique id and timestamp" do
      event = Event.new(:user_created, %{user_id: 1})

      assert event.event_name == :user_created
      assert event.data == %{user_id: 1}
      assert {:ok, _} = Ecto.UUID.cast(event.event_id)
      assert %DateTime{time_zone: "Etc/UTC"} = event.emitted_at
      assert event.causation_id == nil
      assert event.correlation_id == event.event_id
      assert event.metadata == %{}

      refute Event.new(:user_created, %{}).event_id == event.event_id
    end

    test "accepts causation, correlation, and metadata options" do
      event =
        Event.new(:user_created, %{},
          causation_id: "cause-1",
          correlation_id: "chain-1",
          metadata: %{actor: "admin"}
        )

      assert event.causation_id == "cause-1"
      assert event.correlation_id == "chain-1"
      assert event.metadata == %{actor: "admin"}
    end
  end

  describe "caused_by/2" do
    test "links a follow-up event to its cause" do
      parent = Event.new(:order_placed, %{}, correlation_id: "chain-1")

      assert Event.caused_by(parent) == [causation_id: parent.event_id, correlation_id: "chain-1"]

      child = Event.new(:invoice_requested, %{}, Event.caused_by(parent))
      assert child.causation_id == parent.event_id
      assert child.correlation_id == "chain-1"
    end

    test "merges extra options" do
      parent = Event.new(:order_placed, %{})

      opts = Event.caused_by(parent, metadata: %{source: "handler"})

      assert opts[:causation_id] == parent.event_id
      assert opts[:correlation_id] == parent.event_id
      assert opts[:metadata] == %{source: "handler"}
    end
  end
end
