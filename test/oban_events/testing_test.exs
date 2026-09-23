defmodule ObanEvents.TestingTest do
  use ExUnit.Case, async: true

  import ObanEvents.Testing

  alias ObanEvents.Event

  defmodule EchoHandler do
    @moduledoc false
    use ObanEvents.Handler

    @impl true
    def handle_event(:user_created, %Event{} = event), do: {:ok, event}
    def handle_event(_event_name, _event), do: :ok
  end

  defmodule TestEventBus do
    @moduledoc false
    use ObanEvents

    @event_handlers %{
      user_created: [ObanEvents.TestingTest.EchoHandler]
    }
  end

  describe "build_event/3" do
    test "builds an event with string keys like handlers receive" do
      event = build_event(:user_created, %{user_id: 1, role: :admin}, metadata: %{actor_id: 2})

      assert %Event{name: :user_created} = event
      assert event.data == %{"user_id" => 1, "role" => "admin"}
      assert event.metadata == %{"actor_id" => 2}
      assert {:ok, _} = Ecto.UUID.cast(event.id)
      assert %DateTime{} = event.emitted_at
      assert event.correlation_id == event.id
    end

    test "defaults to empty data" do
      assert %Event{data: %{}, metadata: %{}} = build_event(:user_created)
    end

    test "accepts deterministic id and emitted_at" do
      emitted_at = ~U[2025-01-01 00:00:00.000000Z]
      event = build_event(:user_created, %{}, id: "event-1", emitted_at: emitted_at)

      assert event.id == "event-1"
      assert event.emitted_at == emitted_at
    end
  end

  describe "perform_event/4" do
    test "calls the handler with a built event and returns its result" do
      assert {:ok, %Event{} = event} =
               perform_event(EchoHandler, :user_created, %{user_id: 1}, metadata: %{actor_id: 2})

      assert event.name == :user_created
      assert event.data == %{"user_id" => 1}
      assert event.metadata == %{"actor_id" => 2}
    end

    test "defaults to empty data" do
      assert :ok = perform_event(EchoHandler, :other_event)
    end
  end

  describe "to_event/1" do
    test "converts an emitted job into an event" do
      assert {:ok, [job]} =
               TestEventBus.emit(:user_created, %{user_id: 1}, metadata: %{actor_id: 2})

      event = to_event(job)

      assert event.id == job.args["event_id"]
      assert event.name == :user_created
      assert event.data == %{"user_id" => 1}
      assert event.metadata == %{"actor_id" => 2}
    end

    test "converts job args with atom keys" do
      event = to_event(%{event: "user_created", data: %{user_id: 1}, metadata: %{actor_id: 2}})

      assert event.name == :user_created
      assert event.data == %{"user_id" => 1}
      assert event.metadata == %{"actor_id" => 2}
    end
  end
end
