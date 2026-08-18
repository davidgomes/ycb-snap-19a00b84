defmodule ObanEvents.EventTest do
  use ExUnit.Case, async: true

  alias ObanEvents.Event

  describe "new/3" do
    test "creates a new event with defaults" do
      event = Event.new(:user_created)

      assert event.name == :user_created
      assert event.data == %{}
      assert event.metadata == %{}
      assert %DateTime{} = event.timestamp
    end

    test "creates an event with data and metadata" do
      data = %{user_id: 123}
      metadata = %{trace_id: "abc"}
      event = Event.new(:user_created, data, metadata)

      assert event.name == :user_created
      assert event.data == data
      assert event.metadata == metadata
      assert %DateTime{} = event.timestamp
    end
  end
end
