defmodule ObanEvents.EventTest do
  use ExUnit.Case, async: true

  alias ObanEvents.Event

  describe "new/2" do
    test "builds an event with the given name and data" do
      event = Event.new(:user_created, %{"user_id" => 1})

      assert event.name == :user_created
      assert event.data == %{"user_id" => 1}
    end

    test "generates a unique id in metadata" do
      event = Event.new(:user_created, %{})

      assert is_binary(event.metadata.id)
      assert {:ok, _} = Ecto.UUID.dump(event.metadata.id)
    end

    test "generates distinct ids for separate events" do
      event_one = Event.new(:user_created, %{})
      event_two = Event.new(:user_created, %{})

      refute event_one.metadata.id == event_two.metadata.id
    end

    test "generates an emitted_at timestamp in metadata" do
      before = DateTime.utc_now()
      event = Event.new(:user_created, %{})
      after_time = DateTime.utc_now()

      assert %DateTime{} = event.metadata.emitted_at
      assert DateTime.compare(event.metadata.emitted_at, before) in [:eq, :gt]
      assert DateTime.compare(event.metadata.emitted_at, after_time) in [:eq, :lt]
    end
  end

  describe "new/3" do
    test "merges custom metadata with the generated defaults" do
      event = Event.new(:user_created, %{}, %{source: "signup_form"})

      assert event.metadata.source == "signup_form"
      assert is_binary(event.metadata.id)
      assert %DateTime{} = event.metadata.emitted_at
    end

    test "custom metadata cannot override the generated id or emitted_at" do
      custom_time = ~U[2000-01-01 00:00:00Z]

      event =
        Event.new(:user_created, %{}, %{id: "custom-id", emitted_at: custom_time, source: "cli"})

      refute event.metadata.id == "custom-id"
      refute event.metadata.emitted_at == custom_time
      assert event.metadata.source == "cli"
    end
  end

  describe "struct enforcement" do
    test "requires :name and :data" do
      assert_raise ArgumentError, fn ->
        struct!(Event, metadata: %{})
      end
    end
  end
end
