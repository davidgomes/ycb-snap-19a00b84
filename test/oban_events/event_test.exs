defmodule ObanEvents.EventTest do
  use ExUnit.Case, async: true

  alias ObanEvents.Event

  describe "new/3" do
    test "builds an event with the given name and data" do
      event = Event.new(:user_created, %{"user_id" => 1})

      assert event.name == :user_created
      assert event.data == %{"user_id" => 1}
    end

    test "defaults metadata to an empty map" do
      event = Event.new(:user_created, %{})

      assert event.metadata == %{}
    end

    test "accepts additional metadata" do
      event = Event.new(:user_created, %{}, metadata: %{actor_id: 42, source: "signup_form"})

      assert event.metadata == %{actor_id: 42, source: "signup_form"}
    end

    test "defaults emitted_at to the current UTC time" do
      before = DateTime.utc_now()
      event = Event.new(:user_created, %{})
      afterward = DateTime.utc_now()

      assert DateTime.compare(event.emitted_at, before) in [:gt, :eq]
      assert DateTime.compare(event.emitted_at, afterward) in [:lt, :eq]
    end

    test "accepts an explicit emitted_at" do
      timestamp = ~U[2024-01-01 00:00:00Z]
      event = Event.new(:user_created, %{}, emitted_at: timestamp)

      assert event.emitted_at == timestamp
    end

    test "requires name to be an atom" do
      assert_raise FunctionClauseError, fn ->
        Event.new("user_created", %{})
      end
    end

    test "requires data to be a map" do
      assert_raise FunctionClauseError, fn ->
        Event.new(:user_created, "not a map")
      end
    end
  end
end
