defmodule ObanEvents.TestingTest do
  use ExUnit.Case, async: true

  import ObanEvents.Testing

  defmodule EchoHandler do
    @moduledoc false
    @behaviour ObanEvents.Handler

    def handle_event(name, event), do: {:ok, {name, event}}
  end

  test "build_event/3 stringifies keys and fills defaults" do
    event = build_event(:user_created, %{user_id: 1}, metadata: %{actor: "x"})

    assert event.name == :user_created
    assert event.data == %{"user_id" => 1}
    assert event.metadata == %{"actor" => "x"}
    assert is_binary(event.event_id)
    assert %DateTime{} = event.emitted_at
    assert event.attempt == 1
  end

  test "call_handler/4 invokes handler with an event struct" do
    assert {:ok, {:user_created, %ObanEvents.Event{data: %{"id" => 2}}}} =
             call_handler(EchoHandler, :user_created, %{id: 2})
  end
end
