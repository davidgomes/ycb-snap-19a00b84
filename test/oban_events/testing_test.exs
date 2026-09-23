defmodule ObanEvents.TestingTest do
  use ExUnit.Case, async: true

  import ObanEvents.Testing

  alias ObanEvents.Event

  defmodule EchoHandler do
    @moduledoc false
    use ObanEvents.Handler

    @impl true
    def handle_event(name, event), do: {:ok, {name, event}}
  end

  describe "build_event/3" do
    test "builds an event with string keys and generated metadata" do
      event = build_event(:user_created, %{user_id: 1}, metadata: %{source: "test"})

      assert %Event{name: :user_created, data: %{"user_id" => 1}} = event
      assert event.metadata == %{"source" => "test"}
      assert is_binary(event.event_id)
      assert event.correlation_id == event.event_id
      assert %DateTime{} = event.emitted_at
    end
  end

  describe "call_handler/4" do
    test "invokes the handler with a built event" do
      assert {:ok, {:user_created, %Event{} = event}} =
               call_handler(EchoHandler, :user_created, %{user_id: 1})

      assert event.data == %{"user_id" => 1}
      assert event.handler == EchoHandler
    end
  end

  describe "Event.caused_by/1" do
    test "propagates causation and correlation ids" do
      parent = build_event(:parent)
      child = build_event(:child, %{}, Event.caused_by(parent))

      assert child.causation_id == parent.event_id
      assert child.correlation_id == parent.correlation_id
      refute child.event_id == parent.event_id
    end
  end

  describe "events_from_jobs/1" do
    test "round-trips events through job args" do
      event = build_event(:user_created, %{user_id: 1}, metadata: %{a: 1})
      job = %Oban.Job{id: 7, attempt: 2, args: Event.to_args(event, EchoHandler)}

      assert [decoded] = events_from_jobs([job])
      assert decoded.event_id == event.event_id
      assert decoded.data == event.data
      assert decoded.metadata == event.metadata
      assert decoded.emitted_at == event.emitted_at
      assert decoded.handler == EchoHandler
      assert decoded.job_id == 7
      assert decoded.attempt == 2
    end
  end
end
