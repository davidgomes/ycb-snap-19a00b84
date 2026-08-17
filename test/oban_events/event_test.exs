defmodule ObanEvents.EventTest do
  use ExUnit.Case, async: true

  alias ObanEvents.Event

  describe "new/3 and new/4" do
    test "builds an event with a generated id and emitted_at timestamp" do
      before = DateTime.utc_now()

      event = Event.new(:user_created, %{"user_id" => 1}, MyHandler)

      assert event.name == :user_created
      assert event.data == %{"user_id" => 1}
      assert event.handler == MyHandler
      assert event.metadata == %{}
      assert is_binary(event.id)
      assert String.length(event.id) == 32
      assert DateTime.compare(event.emitted_at, before) in [:eq, :gt]
    end

    test "accepts additional metadata" do
      event =
        Event.new(:user_created, %{"user_id" => 1}, MyHandler, %{
          actor_id: 42,
          source: "admin_panel"
        })

      assert event.metadata == %{actor_id: 42, source: "admin_panel"}
    end

    test "generates a unique id for every event" do
      event_one = Event.new(:user_created, %{}, MyHandler)
      event_two = Event.new(:user_created, %{}, MyHandler)

      assert event_one.id != event_two.id
    end

    test "requires name to be an atom" do
      assert_raise FunctionClauseError, fn ->
        Event.new("user_created", %{}, MyHandler)
      end
    end

    test "requires data to be a map" do
      assert_raise FunctionClauseError, fn ->
        Event.new(:user_created, "not a map", MyHandler)
      end
    end

    test "requires handler to be an atom" do
      assert_raise FunctionClauseError, fn ->
        Event.new(:user_created, %{}, "MyHandler")
      end
    end

    test "requires metadata to be a map" do
      assert_raise FunctionClauseError, fn ->
        Event.new(:user_created, %{}, MyHandler, "not a map")
      end
    end
  end

  describe "to_args/1" do
    test "serializes an event into DispatchWorker job args" do
      event =
        Event.new(:user_created, %{"user_id" => 1}, ObanEvents.EventTest.SomeHandler, %{
          source: "admin_panel"
        })

      args = Event.to_args(event)

      assert args["event"] == "user_created"
      assert args["handler"] == "Elixir.ObanEvents.EventTest.SomeHandler"
      assert args["data"] == %{"user_id" => 1}
      assert args["metadata"] == %{source: "admin_panel"}
      assert args["event_id"] == event.id
      assert args["emitted_at"] == DateTime.to_iso8601(event.emitted_at)
    end

    test "defaults metadata to an empty map when none was provided" do
      event = Event.new(:user_created, %{}, ObanEvents.EventTest.SomeHandler)

      assert Event.to_args(event)["metadata"] == %{}
    end
  end
end
