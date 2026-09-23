defmodule ObanEvents.EventTest do
  use ExUnit.Case, async: true

  alias ObanEvents.Event

  describe "new/3" do
    test "generates an id and timestamp and starts a new correlation chain" do
      event = Event.new(:user_created, %{user_id: 1})

      assert event.name == :user_created
      assert event.data == %{"user_id" => 1}
      assert event.metadata == %{}
      assert {:ok, _uuid} = Ecto.UUID.cast(event.event_id)
      assert event.causation_id == nil
      assert event.correlation_id == event.event_id
      assert %DateTime{time_zone: "Etc/UTC"} = event.emitted_at
    end

    test "stringifies nested data and metadata keys" do
      event = Event.new(:e, %{a: %{b: [%{c: 1}]}}, metadata: %{source: %{name: "api"}})

      assert event.data == %{"a" => %{"b" => [%{"c" => 1}]}}
      assert event.metadata == %{"source" => %{"name" => "api"}}
    end

    test ":caused_by sets causation and inherits correlation" do
      root = Event.new(:root, %{})
      child = Event.new(:child, %{}, caused_by: root)
      grandchild = Event.new(:grandchild, %{}, caused_by: child)

      assert child.causation_id == root.event_id
      assert child.correlation_id == root.event_id
      assert grandchild.causation_id == child.event_id
      assert grandchild.correlation_id == root.event_id
    end

    test "explicit ids take precedence over :caused_by" do
      parent = Event.new(:parent, %{})

      event =
        Event.new(:child, %{},
          caused_by: parent,
          event_id: "id",
          causation_id: "cause",
          correlation_id: "corr",
          emitted_at: ~U[2026-01-01 00:00:00Z]
        )

      assert %Event{
               event_id: "id",
               causation_id: "cause",
               correlation_id: "corr",
               emitted_at: ~U[2026-01-01 00:00:00Z]
             } = event
    end

    test "raises when metadata is not a map" do
      assert_raise ArgumentError, ~r/:metadata to be a map/, fn ->
        Event.new(:e, %{}, metadata: [actor_id: 1])
      end
    end
  end

  describe "to_args/2 and from_args/2" do
    test "round-trip an event" do
      event = Event.new(:user_created, %{id: 1}, metadata: %{actor: "admin"})
      args = Event.to_args(event, SomeHandler)

      assert args["event"] == "user_created"
      assert args["handler"] == "Elixir.SomeHandler"
      assert Event.from_args(:user_created, args) == event
    end
  end
end
