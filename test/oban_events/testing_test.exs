defmodule ObanEvents.TestingTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import ObanEvents.Testing

  alias ObanEvents.Event

  defmodule TestHandler do
    @moduledoc false
    use ObanEvents.Handler

    @impl true
    def handle_event(:echo, %Event{} = event) do
      send(self(), {:handled, event})
      :ok
    end

    def handle_event(:fail, _event), do: {:error, :boom}
  end

  describe "build_event/3" do
    test "builds an event with JSON round-tripped data and metadata" do
      event = build_event(:echo, %{id: 1, on: ~D[2026-01-02]}, metadata: %{kind: :api})

      assert %Event{name: :echo, data: data, metadata: metadata} = event
      assert data == %{"id" => 1, "on" => "2026-01-02"}
      assert metadata == %{"kind" => "api"}
      assert event.correlation_id == event.event_id
    end

    test "defaults to empty data" do
      assert %Event{data: %{}} = build_event(:echo)
    end
  end

  describe "perform_event/4" do
    test "runs the handler through the dispatch worker" do
      parent = build_event(:parent)

      assert :ok = perform_event(TestHandler, :echo, %{id: 1}, caused_by: parent)

      assert_received {:handled, %Event{name: :echo, data: %{"id" => 1}} = event}
      assert event.causation_id == parent.event_id
      assert %DateTime{} = event.emitted_at
    end

    test "returns handler errors" do
      capture_log(fn ->
        assert {:error, :boom} = perform_event(TestHandler, :fail, %{})
      end)
    end
  end

  describe "emission assertions" do
    test "reject unknown options" do
      assert_raise ArgumentError, ~r/unknown options: \[:dat\]/, fn ->
        ObanEvents.Testing.assert_event_emitted([repo: ObanEvents.Test.Repo], :echo, dat: %{})
      end
    end

    test "use requires a :repo option" do
      assert_raise ArgumentError, ~r/requires a :repo option/, fn ->
        Code.eval_quoted(
          quote do
            defmodule NoRepo do
              use ObanEvents.Testing
            end
          end
        )
      end
    end
  end
end
