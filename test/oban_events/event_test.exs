defmodule ObanEvents.EventTest do
  use ExUnit.Case, async: true

  alias ObanEvents.Event

  describe "new/3" do
    test "builds an event with the given name and data" do
      event = Event.new(:user_created, %{"user_id" => 1})

      assert event.name == :user_created
      assert event.data == %{"user_id" => 1}
    end

    test "generates a unique id for each event" do
      event_one = Event.new(:user_created, %{})
      event_two = Event.new(:user_created, %{})

      assert is_binary(event_one.id)
      assert event_one.id != event_two.id
    end

    test "sets emitted_at to the current UTC time" do
      before = DateTime.utc_now()
      event = Event.new(:user_created, %{})
      afterward = DateTime.utc_now()

      assert DateTime.compare(event.emitted_at, before) in [:gt, :eq]
      assert DateTime.compare(event.emitted_at, afterward) in [:lt, :eq]
    end

    test "defaults metadata to an empty map" do
      event = Event.new(:user_created, %{})

      assert event.metadata == %{}
    end

    test "stores caller-supplied metadata" do
      event = Event.new(:user_created, %{}, %{source: "signup_form"})

      assert event.metadata == %{source: "signup_form"}
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

  describe "to_job_args/2" do
    test "includes event, handler, and data" do
      event = Event.new(:user_created, %{"user_id" => 1})
      args = Event.to_job_args(event, MyApp.EmailHandler)

      assert args["event"] == "user_created"
      assert args["handler"] == "Elixir.MyApp.EmailHandler"
      assert args["data"] == %{"user_id" => 1}
    end

    test "includes event_id and emitted_at in metadata" do
      event = Event.new(:user_created, %{})
      args = Event.to_job_args(event, MyApp.EmailHandler)

      assert args["metadata"]["event_id"] == event.id
      assert args["metadata"]["emitted_at"] == DateTime.to_iso8601(event.emitted_at)
    end

    test "merges caller-supplied metadata alongside event_id and emitted_at" do
      event = Event.new(:user_created, %{}, %{source: "signup_form"})
      args = Event.to_job_args(event, MyApp.EmailHandler)

      assert args["metadata"]["source"] == "signup_form"
      assert args["metadata"]["event_id"] == event.id
    end

    test "produces a JSON-serializable map" do
      event = Event.new(:user_created, %{"user_id" => 1}, %{source: "signup_form"})
      args = Event.to_job_args(event, MyApp.EmailHandler)

      assert {:ok, _json} = Jason.encode(args)
    end
  end
end
