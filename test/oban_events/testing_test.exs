defmodule ObanEvents.TestingTest do
  use ExUnit.Case, async: true

  import ObanEvents.Testing

  alias ObanEvents.Event

  defmodule Handler do
    @moduledoc false
    use ObanEvents.Handler

    @impl true
    def handle_event(name, event) do
      send(self(), {:handled, name, event})
      :ok
    end
  end

  test "build_event/3 stringifies keys and sets tracing ids" do
    event = build_event(:thing_happened, %{id: 1}, metadata: %{actor: "x"})

    assert %Event{name: :thing_happened, data: %{"id" => 1}, metadata: %{"actor" => "x"}} =
             event

    assert is_binary(event.id)
    assert event.correlation_id == event.id
    assert %DateTime{} = event.emitted_at
  end

  test "build_event/3 with :caused_by chains ids" do
    parent = build_event(:parent)
    child = build_event(:child, %{}, caused_by: parent)

    assert child.causation_id == parent.id
    assert child.correlation_id == parent.correlation_id
  end

  test "perform_event/4 runs handler through the worker" do
    assert :ok = perform_event(Handler, :thing_happened, %{id: 1}, metadata: %{k: "v"})
    assert_received {:handled, :thing_happened, %Event{data: %{"id" => 1}, metadata: %{"k" => "v"}}}
  end

  test "event_args/3 builds stable job args" do
    assert event_args(:thing_happened, Handler, %{id: 1}) == %{
             "event" => "thing_happened",
             "handler" => "Elixir.ObanEvents.TestingTest.Handler",
             "data" => %{"id" => 1}
           }
  end
end
